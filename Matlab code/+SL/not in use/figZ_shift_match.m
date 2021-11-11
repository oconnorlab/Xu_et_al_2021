%% 

clear
areaName = 'ZZ';
datDir = SL.Param.GetAnalysisRoot;
figDir = fullfile(datDir, SL.Param.figDirName, 'FigZ');


%% Find time shifts

% Load cached decoding results which have mean angle traces
cachePath = fullfile(figDir, ['dec seq_zz-seq_zz-seq_zz ' areaName]);
load(cachePath, 'mcomTb', 'sReg');

% Extract angle time series
ia = sReg(1).sInd(strcmp(sReg(1).subNames, 'tongue_bottom_angle'));
aa = zeros(numel(mcomTb.time{1}), height(mcomTb));
for i = 1 : height(mcomTb)
    isRare = mcomTb.stim{i}(:,ia,5) > 0.8; % ignore time points that have more than 80% NaNs
    aa(:,i) = mcomTb.stim{i}(:,ia,1);
    aa(isRare,i) = NaN;
end

% Find indices to shift by
sShift = SL.ZZ.FindShifts(aa(:,1), aa(:,2), SL.Param.minISI);

% % Cache shifting info
% save(fullfile(figDir, ['sShift ' areaName '.mat']), 'sShift');


%% Plot matching result

f = MPlot.Figure(188005); clf
SL.ZZ.PlotShifted(mcomTb.time{1}, aa, sShift);
MPlot.Paperize(f, 'ColumnsWide', .7, 'Aspect', 1);
% saveFigurePDF(f, fullfile(figDir, 'shifting'));

