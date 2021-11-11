%% Collect input data

gtPaths = MBrowse.Files([], 'Select ground truth file(s)', '.mat');

tbAll = table();

for i = length(gtPaths) : -1 : 1
    load(gtPaths{i}, 'gTruth');
    
    % Image sources
    tbAll.image{i} = gTruth.DataSource.Source;
    hasTongue = gTruth.LabelData.tongue_state;
    tbAll.image_has_tongue{i} = gTruth.DataSource.Source(hasTongue);
    
    % For scene classification
    tbAll.tongue_state{i} = categorical(hasTongue);
    
    % For regression
    lmCoor = gTruth.LabelData.tongue_bottom_lm(hasTongue);
    lmNum = size(lmCoor{1},1);
    lmCoor = cellfun(@(x) x([lmNum/2 lmNum],:), lmCoor, 'Uni', false);
    lmCoor = cell2mat(cellfun(@(x) x(:)', lmCoor, 'Uni', false));
    tbAll.tongue_bottom_lm{i} = lmCoor;
end

indAll = 1 : height(tbAll);
indTest = 11;
indTrain = setdiff(indAll, indTest);


%% Classification - setup training and testing sets

outputSize = [224 224 3]; % for vgg16 or resnet

imageAugmenter = imageDataAugmenter( ...
    'RandXReflection', true, ...
    'RandXTranslation', [-25 25], ...
    'RandYTranslation', [-50 50], ...
    'RandRotation', [-90 90], ...
    'RandXScale', [0.8 1.2], ...
    'RandYScale', [0.8 1.2]);

imdsTrainClass = augmentedImageDatastore(outputSize, ...
    MNN.DenestTable(tbAll(indTrain, {'image', 'tongue_state'})), ...
    'ColorPreprocessing', 'gray2rgb', ...
    'DataAugmentation', imageAugmenter);


%% Classification - construct networks

% Get a pretrained net
net = resnet50('Weights', 'imagenet');

% Define new layers
layersClass = [
    fullyConnectedLayer(2, 'WeightLearnRateFactor', 20, 'BiasLearnRateFactor', 20, 'Name', 'fc_class')
    softmaxLayer('Name', 'softmax')
    classificationLayer('Name', 'class')];

% Do surgery
lgraphClass = layerGraph(net);
lgraphClass = removeLayers(lgraphClass, {'fc1000', 'fc1000_softmax', 'ClassificationLayer_fc1000'});
lgraphClass = addLayers(lgraphClass, layersClass);
lgraphClass = connectLayers(lgraphClass, 'avg_pool', 'fc_class');


%% Classification - train networks

%{
On 1070Ti (8GB memory), alexnet can use a minibatch size of 128 with validation. vgg16 can only use up to 32.
%}

% Training options
optionsClass = trainingOptions('sgdm', ...
    'MiniBatchSize', 32, ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-4, ...
    'Shuffle', 'every-epoch', ...
    'Verbose', false, ...
    'Plots', 'training-progress', ...
    'CheckpointPath', 'D:\NN workspace\nets\tongue_state')
%     'ValidationData', imdsTestClass, ...
%     'ValidationFrequency', 200, ...
%     'ValidationPatience', Inf, ...

[net, trainInfo] = trainNetwork(imdsTrainClass, lgraphClass, optionsClass);

save(fullfile(optionsClass.CheckpointPath, 'finished_net.mat'), 'net', 'trainInfo');


%% Regression - setup training and testing sets

outputSize = [224 224 3];

imageAugmenter = imageDataAugmenter( ...
    'RandXReflection', true, ...
    'RandXTranslation', [-20 20], ...
    'RandYTranslation', [-20 20], ...
    'RandRotation', [-45 45], ...
    'RandXScale', [0.9 1.1], ...
    'RandYScale', [0.9 1.1]);

imgTrainReg = cellfun(@imread, cat(1, tbAll.image_has_tongue{:}), 'Uni', false);
imgTrainReg = cat(3, imgTrainReg{:});
lmTrainReg = cell2mat(tbAll.tongue_bottom_lm);

imgTrainRegAug = imgTrainReg;
lmTrainRegAug = lmTrainReg;
for i = 1 : size(imgTrainReg, 3)
    lmMat = reshape(lmTrainReg(i,:), [size(lmTrainReg,2)/2, 2]);
    [imgTrainRegAug(:,:,i), lmMat] = MNN.AugmentImage(imageAugmenter, imgTrainReg(:,:,i), lmMat);
    lmTrainRegAug(i,:) = lmMat(:);
end

% MImgBaseClass.Viewer(imgTrainRegAug, 'UserFunc', {@SL.HSV.ViewerUserFunc2, [], lmTrainRegAug, []})

imdsTrainReg = augmentedImageDatastore(outputSize, permute(imgTrainRegAug, [1 2 4 3]), lmTrainRegAug, ...
    'ColorPreprocessing', 'gray2rgb');


%% Regression - construct networks

% Get a pre-trained network
net = resnet50('Weights', 'imagenet');

% Define new layers
numVals = size(lmCoor, 2);
layersReg = [
    fullyConnectedLayer(numVals, 'Name', 'fc_reg')
    regressionMAELayer('regMAE')];

% Do surgery
lgraphReg = layerGraph(net);
lgraphReg = removeLayers(lgraphReg, {'fc1000', 'fc1000_softmax', 'ClassificationLayer_fc1000'});
lgraphReg = addLayers(lgraphReg, layersReg);
lgraphReg = connectLayers(lgraphReg, 'avg_pool', 'fc_reg');

% figure(123); clf; lgraphReg.plot(); ylim([0 length(lgraphReg.Layers)+1])


%% Regression - train networks

% Contunue training from a previously saved net
% lgraphReg = net;

% Training options
optionsReg = trainingOptions('sgdm', ...
    'MiniBatchSize', 32, ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-4, ...
    'Shuffle', 'every-epoch', ...
    'Verbose', false, ...
    'Plots', 'training-progress', ...
    'CheckpointPath', 'D:\NN workspace\nets\tongue_bottom_lm')

% Train network
[net, trainInfo] = trainNetwork(imdsTrainReg, lgraphReg, optionsReg);

save(fullfile(optionsReg.CheckpointPath, 'finished_net.mat'), 'net', 'trainInfo');


%% Regression - continue training

% Training options
optionsReg = trainingOptions('sgdm', ...
    'MiniBatchSize', 32, ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-5, ...
    'Shuffle', 'every-epoch', ...
    'Verbose', false, ...
    'Plots', 'training-progress', ...
    'CheckpointPath', 'D:\NN workspace\nets\tongue_bottom_lm')

% Train network
[net, trainInfo] = trainNetwork(imdsTrainReg, layerGraph(net), optionsReg);

save(fullfile(optionsReg.CheckpointPath, 'finished_net.mat'), 'net', 'trainInfo');


%% Collect input data

gtPaths = MBrowse.Files([], 'Select ground truth file(s)', '.mat');

tbAll = table();

for i = length(gtPaths) : -1 : 1
    load(gtPaths{i}, 'gTruth');
    
    % Image sources
    hasTongue = gTruth.LabelData.tongue_state;
    tbAll.image_has_tongue{i} = gTruth.DataSource.Source(hasTongue);
    
    % For segmentation
    tbAll.pixelLabel{i} = gTruth.LabelData.PixelLabelData(hasTongue);
end

pxLabelDefs = gTruth.LabelDefinitions(gTruth.LabelDefinitions.Type == labelType.PixelLabel, :);


%% Segmentation - setup training and testing sets

outputSize = [224 224 3];

imageAugmenter = imageDataAugmenter( ...
    'RandXReflection', true, ...
    'RandXTranslation', [-25 25], ...
    'RandYTranslation', [-25 50], ...
    'RandRotation', [-45 45], ...
    'RandXScale', [0.9 1.1], ...
    'RandYScale', [0.9 1.1]);

imdsTrainSeg = imageDatastore(cat(1, tbAll.image_has_tongue{indTrain}));
pxdsTrainSeg = pixelLabelDatastore(cat(1, tbAll.pixelLabel{indTrain}), pxLabelDefs.Name, pxLabelDefs.PixelLabelID);
pximdsTrainSeg = pixelLabelImageDatastore(imdsTrainSeg, pxdsTrainSeg, ...
    'OutputSize', outputSize, ...
    'ColorPreprocessing', 'gray2rgb', ...
    'DataAugmentation', imageAugmenter);


%% Segmentation - construct networks

% Construct SegNet from a pre-trained network
numClasses = height(pxLabelDefs);
lgraphSeg = segnetLayers(outputSize, numClasses, 'vgg16');

% Balance weights by pixel counts
pxCountTb = countEachLabel(pxdsTrainSeg);
pxFraction = pxCountTb.PixelCount ./ pxCountTb.ImagePixelCount;
classWeights = median(pxFraction) ./ pxFraction;
classWeights = [1 1];

% Do surgery
pxLayer = pixelClassificationLayer('Name', 'labels', 'ClassNames', pxCountTb.Name, 'ClassWeights', classWeights);
lgraphSeg = removeLayers(lgraphSeg, 'pixelLabels');
lgraphSeg = addLayers(lgraphSeg, pxLayer);
lgraphSeg = connectLayers(lgraphSeg, 'softmax', 'labels');


%% Segmentation - train networks

% Training options
optionsSeg = trainingOptions('sgdm', ...
    'Momentum', 0.9, ...
    'InitialLearnRate', 1e-3, ...
    'L2Regularization', 0.0005, ...
    'MaxEpochs', 15, ...
    'MiniBatchSize', 8, ...
    'CheckpointPath', 'D:\NN workspace\nets\segmentation', ...
    'Shuffle', 'every-epoch', ...
    'VerboseFrequency', 2, ...
    'Plots', 'training-progress')

[net, trainInfo] = trainNetwork(pximdsTrainSeg, lgraphSeg, optionsSeg);

save(fullfile(optionsSeg.CheckpointPath, 'finished_net.mat'), 'net', 'trainInfo');




