%% Load SE and specify video paths

mainDir = '';

sePath = MBrowse.File([], 'Select a SE file');
% sePath = fullfile(mainDir, 'NH190201 2019-07-23 s2 se enriched.mat');
se = SL.SE.LoadSession(sePath);

vidPaths = MBrowse.Files([], 'Select video files');
% vidPaths = { ...
%     fullfile(mainDir, 'NH190201_190723_s1.avi'); ...
%     fullfile(mainDir, 'NH190201_190723_s3.avi'); ...
%     };
disp(vidPaths)

if isfield(se.userData, 'cameraInfo')
    alignTb = se.userData.cameraInfo.alignTb;
else
    alignTb = table();
end
alignTb.vidPaths = vidPaths;
[~, alignTb.vidNames] = cellfun(@fileparts, vidPaths, 'Uni', false);


%% Import video

iVid = 3;
vidObj = VideoReader(vidPaths{iVid});

% Specify the location of the ROI
roiRow = (vidObj.Height-150+1) : vidObj.Height;
roiCol = 1 : 100;

% Get ROI from all frames
s = struct('cdata', [], 'time', 0);
vidObj.CurrentTime = 0;
k = 0;
while hasFrame(vidObj)
    fr = rgb2gray(readFrame(vidObj));
    roi = imresize(fr(roiRow, roiCol), [75 NaN], 'nearest');
    
    k = k + 1;
    s(k).cdata = roi;
    s(k).time = vidObj.CurrentTime;
    
    if mod(k, 100) == 0
        fprintf('%i/%i\n', k, vidObj.FrameRate * vidObj.Duration);
    end
end
disp('Done!')
vid = cat(ndims(s(k).cdata)+1, s.cdata);
t = cat(1, s.time);


%% Align time

% Convert ROI brightness to binary values
lum = squeeze(mean(mean(vid, 1), 2));   % average ROI pixel values
midVal = (max(lum) + min(lum)) / 2;     % set a threshold
lum = lum > midVal;                     % threshold intensity to binary

% Find times of blinking
dlum = [0; diff(lum)];
tLed = t(dlum ~= 0);

% Get times of signal change in Intan
tIntanOn = se.userData.delimiterData.delimiterRiseTime;
tIntanOff = tIntanOn + se.userData.delimiterData.delimiterDur;
tIntan = sort([tIntanOn; tIntanOff]);

% Compute time shift using discrete cross-correlation
tEdges = -6e2:(1/vidObj.FrameRate):tIntan(end);
tCenters = tEdges(1:end-1) + diff(tEdges)/2;
ccg = MNeuro.CCG(tEdges, tIntan, tLed);
ccg = squeeze(ccg(1,2,:));
[~, iMax] = max(ccg);
tShift = tCenters(iMax);

% Match time points
[D, iIntan] = min(abs(tIntan - (tLed+tShift)'));
[~, aLed] = min(D);
aIntan = iIntan(aLed);
% [D, iLed] = min(abs(tIntan - (tLed+tShift)'));
% [~, aIntan] = min(D);
% aLed = iLed(aIntan);

lenPreLed = aLed - 1;
lenPreIntan = aIntan - 1;
lenPostLed = length(tLed) - aLed;
lenPostIntan = length(tIntan) - aIntan;
lenPreMin = min(lenPreLed, lenPreIntan);
lenPostMin = min(lenPostLed, lenPostIntan);

tIntan = tIntan((aIntan-lenPreMin):(aIntan+lenPostMin));
tLed = tLed((aLed-lenPreMin):(aLed+lenPostMin));

% Add results to alignTb
alignTb.tIntan{iVid} = tIntan;
alignTb.tLed{iVid} = tLed;


figure(1); clf
plot(tCenters, ccg)

figure(2); clf
% plot([0 900]', [0 900]', 'Color', [0 0 0 .3]); hold on
plot(tLed, tIntan, 'o');
% xlim([0 900])
% ylim([0 900])
axis square


%% Save new SE

% Add video and alignment info
cameraInfo = struct();
cameraInfo.frameRate = vidObj.FrameRate;
cameraInfo.alignTb = alignTb;
se.userData.cameraInfo = cameraInfo;

save(sePath, 'se');




