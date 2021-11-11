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

% Report numbers
fprintf('Classification: %i frames for training, %i frames for testing\n', ...
    sum(cellfun(@numel, tbAll.image(indTrain))), ...
    sum(cellfun(@numel, tbAll.image(indTest))));

fprintf('Regression: %i frames for training, %i frames for testing\n', ...
    sum(cellfun(@numel, tbAll.image_has_tongue(indTrain))), ...
    sum(cellfun(@numel, tbAll.image_has_tongue(indTest))));


%% Classification

% Setup testing sets
outputSize = [224 224 3]; % for vgg16 or resnet
imdsTestClass = augmentedImageDatastore(outputSize, ...
    MNN.DenestTable(tbAll(indTest, {'image', 'tongue_state'})), ...
    'ColorPreprocessing', 'gray2rgb');

% Load a trained network
load('finished_net_is_tongue_out_20180831-01.mat');

% Testing
[CTestPred, CTestScore] = classify(net, imdsTestClass);
CTestGt = cat(1, tbAll.tongue_state{indTest});

% Tabulate the results using a confusion matrix.
confMat = confusionmat(CTestGt, CTestPred);
confMat = confMat ./ sum(confMat,2);

% Plot
figure
h = heatmap({'Tongue In', 'Tongue Out'}, {'Tongue In', 'Tongue Out'}, 100 * confMat);
h.XLabel = 'Predicted Class';
h.YLabel = 'True Class';
h.Title  = 'Normalized Confusion Matrix (%)';

save('computed confMat.mat', 'confMat');


%% Regression - setup training and testing sets

% Setup testing sets
outputSize = [224 224 3];

imdsTestReg = augmentedImageDatastore(outputSize, ...
    MNN.DenestTable(tbAll(indTest, {'image_has_tongue', 'tongue_bottom_lm'})), ... %cat(1, tbAll.image_has_tongue{indTest}), ...
    'ColorPreprocessing', 'gray2rgb');

% Load a trained network
load('finished_net_tongue_bottom_lm_20180901-01-stage4.mat');

% Testing
YTestPred = predict(net, imdsTestReg);
YTestGt = cat(1, tbAll.tongue_bottom_lm{indTest});

% 
YErr = YTestPred - YTestGt;
YErrDist = sqrt(YErr(:,1:2).^2 + YErr(:,3:4).^2);

[L, A] = SL.HSV.Landmarks2Kinematics(YTestGt);
[Lhat, Ahat] = SL.HSV.Landmarks2Kinematics(YTestPred);
Ldiff = Lhat - L;
Adiff = Ahat - A;

fprintf('Error in angle %.2g±%.2g° mean±SD\n', mean(Adiff), std(Adiff));
fprintf('Error in length %.2g±%.2g mm mean±SD\n', mean(Ldiff), std(Ldiff));


% Plot
% figure
% boxplot(YErrDist);
% xlabel('Point');
% ylabel('Distance to ground truth (pixel)');

MPlot.Figure(6436); clf
subplot(2,1,1)
histogram(Ldiff, 'Normalization', 'probability');
xlabel('Error (mm)');
subplot(2,1,2)
histogram(Adiff, 'Normalization', 'probability');
xlabel('Error (°)');


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

indAll = 1 : height(tbAll);
indTest = 1; % this is a placeholder
indTrain = setdiff(indAll, indTest);

% Report numbers
fprintf('Segmentation: %i frames for training, %i frames for testing\n', ...
    sum(cellfun(@numel, tbAll.image_has_tongue(indTrain))), ...
    sum(cellfun(@numel, tbAll.image_has_tongue(indTest))));


%% Segmentation

% Setup testing sets
outputSize = [224 224 3];
imdsTestSeg = imageDatastore(cat(1, tbAll.image_has_tongue{indTest}));
imdsTestSeg.ReadFcn = @(x) imresize(MNN.ReadImage2RGB(x), outputSize(1:2));
pxdsTestSeg = pixelLabelDatastore(cat(1, tbAll.pixelLabel{indTest}), pxLabelDefs.Name, pxLabelDefs.PixelLabelID);
pxdsTestSeg.ReadFcn = @(x) imresize(imread(x), outputSize(1:2), 'nearest');

% Load a trained network
load('finished_net_tongue_bottom_area_20180829-01.mat');

% Testing
pxdsResults = semanticseg(imdsTestSeg, net, "WriteLocation", tempdir, 'MiniBatchSize', 8);

metrics = evaluateSemanticSegmentation(pxdsResults, pxdsTestSeg);
metrics.ClassMetrics
metrics.ConfusionMatrix

normConfMatData = metrics.NormalizedConfusionMatrix.Variables;
figure
h = heatmap(pxLabelDefs.Name, pxLabelDefs.Name, 100 * normConfMatData);
h.XLabel = 'Predicted Class';
h.YLabel = 'True Class';
h.Title  = 'Normalized Confusion Matrix (%)';

imageIoU = metrics.ImageMetrics.MeanIoU;
figure
histogram(imageIoU)
title('Image Mean IoU')

imgTestSeg = imdsTestSeg.readall();
imgTestSeg = cellfun(@rgb2gray, imgTestSeg, 'Uni', false);
imgTestSeg = cat(3, imgTestSeg{:});

pxTestSeg = pxdsTestSeg.readall();
pxTestSeg = cat(3, pxTestSeg{:}) == 'tongue_bottom_area';

pxPredSeg = pxdsResults.readall();
pxPredSeg = cat(3, pxPredSeg{:}) == 'tongue_bottom_area';

MImgBaseClass.Viewer(imgTestSeg, 'UserFunc', {@SL.HSV.ViewerUserFunc3, pxTestSeg, pxPredSeg})




