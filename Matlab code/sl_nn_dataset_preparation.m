%% Save video frames to image files

vidFilePaths = MBrowse.Files([], 'Select video file(s)', '.avi');

datasetDir = MBrowse.Folder('D:\NN workspace\data', 'Select a folder to save the dataset');

roiTemplate = imread(fullfile(datasetDir, 'roi_template.tif')); % figure; imshow(frTemp);

mkdir(datasetDir, 'mugshots');

for i = 1 : length(vidFilePaths)
    % Create a folder named by trial ID
    [~, trialId] = fileparts(vidFilePaths{i});
    mkdir(datasetDir, trialId);
    
    % Read all video frames
    vid = MNN.ReadVideo(vidFilePaths{i}, 'FrameFunc', @rgb2gray);
    
    % Find ROI by image registration with a template
    [vidTf, tform] = MNN.RoiTransform(vid, roiTemplate, 'X');
    
    % Save transformation object
    save(fullfile(datasetDir, trialId, 'tform.mat'), 'tform');
    
    % Save individual frames to image files
    for k = 1 : size(vidTf,3)
        imgFileName = [trialId '_' sprintf('%.5d', k) '.tif'];
        disp(imgFileName);
        imwrite(vidTf(:,:,k), fullfile(datasetDir, trialId, imgFileName));
    end
    
    % Check result and save a mugshot (last frame)
    figure(i); clf
    imshow(vidTf(:,:,k));
    title(trialId, 'Interpreter', 'none');
    imwrite(vidTf(:,:,k), fullfile(datasetDir, 'mugshots', imgFileName));
end


%% Construct and save groundTruth objects

datasetDir = MBrowse.Folder('D:\NN workspace\data', 'Select the dataset folder');

gtPaths = MBrowse.Files([], 'Select ground truth or landmarks file(s)', '.mat');

isForSegmentation = true;

% Define labels
labelDefs = table();
if isForSegmentation
    labelDefs.Name = {'tongue_bottom_lm'; 'tongue_state'; 'tongue_bottom_area'; 'background_area'};
    labelDefs.Type = [labelType.Line; labelType.Scene; labelType.PixelLabel; labelType.PixelLabel];
    labelDefs.PixelLabelID = {[]; []; 100; 0};
else
    labelDefs.Name = {'tongue_bottom_lm'; 'tongue_state'};
    labelDefs.Type = [labelType.Line; labelType.Scene];
end
disp(labelDefs);

for i = 1 : length(gtPaths)
    % Load ground truth data
    disp(gtPaths{i});
    gtData = load(gtPaths{i});
    
    % Find source images
    [gtDir, gtFileName] = fileparts(gtPaths{i});
    gtFileNameParts = strsplit(gtFileName, ' ');
    trialId = gtFileNameParts{1};
    imds = imageDatastore(fullfile(datasetDir, trialId));
    dataSource = groundTruthDataSource(imds.Files);
    
    % Get label data
    labelData = table();
    
    load(fullfile(datasetDir, trialId, 'tform.mat'));
    lmCoor = gtData.landmarksTable.tongue_bottom;
    lmCoor = cellfun(@(x) transformPointsForward(tform, x), lmCoor, 'Uni', false);
    labelData.tongue_bottom_lm = lmCoor;
    
    labelData.tongue_state = ~cellfun(@isempty, lmCoor);
    
    if isForSegmentation
        pxLabelDir = fullfile(datasetDir, [trialId ' PixelLabel']);
        mkdir(pxLabelDir);
        imgSize = size(imds.readimage(1));
        for k = 1 : length(imds.Files)
            [~, frName] = fileparts(imds.Files{k});
            pxLabelImgPath = fullfile(pxLabelDir, [frName '.png']);
            
            if ~exist(pxLabelImgPath, 'file')
                disp([frName '.png']);
                pxLabelImg = zeros(imgSize, 'uint8');
                lmX = labelData.tongue_bottom_lm{k}(:,1);
                lmY = labelData.tongue_bottom_lm{k}(:,2);
                roiMask = poly2mask(lmX, lmY, imgSize(1), imgSize(2));
                pxLabelImg(roiMask) = 100;
                imwrite(pxLabelImg, pxLabelImgPath);
            end
            
            labelData.PixelLabelData{k} = pxLabelImgPath;
        end
    end
    
    % Make groundTruth object
    gtData.gTruth = groundTruth(dataSource, labelDefs, labelData);
    gtData.tform = tform;
    save(fullfile(gtDir, [trialId ' ground truth.mat']), '-struct', 'gtData');
end


% vid = imds.readall();
% Img23.Viewer(cat(3,vid{:}), 'UserFunc', {@SL.HSV.ViewerUserFunc, lmCoor});





