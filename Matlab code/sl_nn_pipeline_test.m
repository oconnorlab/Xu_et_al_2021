%% Read video files

vidFilePaths = MBrowse.Files([], 'Select video file(s)', '*.avi');

roiTemplate = imread('roi_template.tif'); % figure; imshow(frTemp);

img = cell(size(vidFilePaths));

for i = 1 : length(vidFilePaths)
    % Read all video frames
    vid = MNN.ReadVideo(vidFilePaths{i});
    
    % Find ROI by image registration with a template
    [vidTf, tform] = MNN.RoiTransform(vid(:,1:500,:,:), roiTemplate , 'X');
    
    % Resize images
    img{i} = imresize(vidTf, [224 224]);
    
    % Check result
    figure(i); clf
    imshow(vidTf(:,:,:,end));
end

img = cat(4, img{:});
size(img)

%% Load networks

netClassName = 'finished_net_is_tongue_out_20180831-01.mat';
netClass = load(netClassName);

netRegName = 'finished_net_tongue_bottom_lm_20180901-01-stage4.mat';
netReg = load(netRegName);

netSegName = 'finished_net_tongue_bottom_area_20180829-01.mat';
netSeg = load(netSegName);

%% Compute

% Run tongue state classification
tic;
[C, C_score] = classify(netClass.net, img);
toc;
reset(parallel.gpu.GPUDevice.current);

% Run tongue landmark regression
tic;
Y = predict(netReg.net, img);
toc;
reset(parallel.gpu.GPUDevice.current);

% Run sementic segmentation
tic;
S = semanticseg(img, netSeg.net, 'MiniBatchSize', 16);
toc;
reset(parallel.gpu.GPUDevice.current);

%% Visualize results

% C_score = zeros(0,2);
% Y = zeros(0,20);
% S = [];

MImgBaseClass.Viewer(img, 'UserFunc', {@SL.HSV.ViewerUserFunc2, C_score(:,2), Y/320*224, S});

%% Save reuslts

s = struct();
s.vidFilePaths = vidFilePaths;
s.img = img;
s.netClassName = netClassName;
s.netRegName = netRegName;
s.netSegName = netSegName;
s.C = C;
s.C_score = C_score;
s.Y = Y;
s.S = S;

save(['C:\Users\Many\Dropbox (oconnorlab)\Documents\RnD\OConnor Lab\Project Tongue\Intermediate data\Fig1\' ...
    'fig1c data MX180202_Num59_20180504_135545.mat'], '-struct', 's');


%% Test pipeline

result = SL.Preprocess.Tracking(vidFilePaths, ...
    'RoiTemplate', roiTemplate, ...
    'ClassNet', netClass.net, ...
    'RegNet', netReg.net);


%% Video making

rec = SL.HSV.MakeVideoMat(img, C_score(:,2), Y/320*224, S);

vidObj = VideoWriter('vid.avi');
vidObj.Quality = 95;
vidObj.FrameRate = 40;

open(vidObj);
writeVideo(vidObj, rec);
close(vidObj);





