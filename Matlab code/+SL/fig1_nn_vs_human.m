%% Quantify the Performance of DNN

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig1');


%% Load data

% Multi-user tracked trials
lmDir = fullfile(SL.Data.analysisRoot, 'Supporting files', 'multi-user landmarks copy');
commonNames = ["MX180201_20180403_Num151_15-20-11"];

% Find videos
aviSearch = MBrowse.Dir2Table(fullfile(lmDir, commonNames + '*.avi'));

% Run DNNs on videos
tkArray = cell(height(aviSearch),1);
for i = 1 : numel(tkArray)
    cachePath = fullfile(figDir, commonNames + " tkData.mat");
    if exist(cachePath, 'file')
        tkData = load(cachePath);
    else
        tkData = SL.HSV.TrackTrial(fullfile(aviSearch.folder, aviSearch.name));
        save(cachePath, '-struct', 'tkData');
    end
    tkArray{i} = tkData;
end

% Load landmarks
lmTbArray = cell(size(commonNames));
for i = 1 : numel(commonNames)
    lmSearch = MBrowse.Dir2Table(fullfile(lmDir, commonNames(i) + ' landmarks*.mat'));
    lmTbArray{i} = table();
    for j = 1 : height(lmSearch)
        load(fullfile(lmSearch.folder{j}, lmSearch.name{j}));
        lmTbArray{i}.(j) = landmarksTable.tongue_bottom;
    end
end
lmCell = cat(1, lmTbArray{:});
lmCell = lmCell{:,:};


%% Derive angle and length

qTb = table();

% From DNN output
qTb.Chat = cell2mat(cellfun(@(x) x.C == 'true', tkArray, 'Uni', false));
Y = cell2mat(cellfun(@(x) x.Y, tkArray, 'Uni', false));
vect = Y(:,[1 3]) - Y(:,[2 4]);
qTb.Lhat = sqrt(vect(:,1).^2 + vect(:,2).^2) * SL.Param.mmPerPx;
qTb.Ahat = atan2d(-vect(:,2), vect(:,1));

% From humans
A = NaN(size(lmCell));
L = NaN(size(lmCell));
for i = 1 : numel(lmCell)
    if isempty(lmCell{i})
        continue;
    end
    coor = lmCell{i}([4 2],:);
    vect = diff(coor);
    L(i) = sqrt(vect(1).^2 + vect(2).^2) * SL.Param.mmPerPx;
    A(i) = atan2d(-vect(2), vect(1));
end
qTb.Lmean = mean(L,2);
qTb.Amean = mean(A,2);
qTb.C = ~isnan(qTb.Lmean);


%% Quantify errors

% % Confusion matrix of classification
% confMat = confusionmat(qTb.C, qTb.Chat);
% confMat = confMat ./ sum(confMat,2); % balance two classes

% Deviation of angle and length
dL = L - qTb.Lmean;
dA = A - qTb.Amean;
dLhat = qTb.Lhat - qTb.Lmean;
dAhat = qTb.Ahat - qTb.Amean;

% Mean deviation of predictions from human mean
dAhatMean = nanmean(dAhat);
dLhatMean = nanmean(dLhat);
[~, ~, dAhatMeanCI] = ttest2(dAhat, dA(:));
[~, ~, dLhatMeanCI] = ttest2(dLhat, dL(:));

% SD of the deviations
sdL = nanstd(dL(:));
sdA = nanstd(dA(:));
sdLhat = nanstd(dLhat(:));
sdAhat = nanstd(dAhat(:));

% Test for equal variance
% [isDiffVarA, pDiffVarA] = ttest2(dAhat-nanmean(dAhat), dA(:));
% [isDiffVarL, pDiffVarL] = ttest2(dLhat-nanmean(dLhat), dL(:));


%% Print stats

fileID = fopen(fullfile(figDir, 'nn perf compared w humans.txt'), 'w');
fprintf(fileID, '%d humans performed labeling\n', height(lmSearch));
fprintf(fileID, '%d frames are involved in classification\n', height(qTb));
fprintf(fileID, '%d frames are involved in regression\n', sum(qTb.C));
fprintf(fileID, '\n');
fprintf(fileID, 'Angle from humans varied from human mean by %s%.2f SD (degree)\n', 177, sdA);
fprintf(fileID, 'Angle from DNN differs from human mean by %.2f (%.2f,%.2f) (degree)\n', ...
    dAhatMean, dAhatMeanCI(1), dAhatMeanCI(2));
fprintf(fileID, 'Angle from DNN varied from human mean by %s%.2f SD (degree)\n', 177, sdAhat);
fprintf(fileID, '\n');
fprintf(fileID, 'Length from humans varied from human mean by %s%.2f SD (mm)\n', 177, sdL);
fprintf(fileID, 'Length from DNN differs from human mean by %.2f (%.2f,%.2f) (mm)\n', ...
    dLhatMean, dLhatMeanCI(1), dLhatMeanCI(2));
fprintf(fileID, 'Length from DNN varied from human mean by %s%.2f SD (mm)\n', 177, sdLhat);
fclose(fileID);


%% Plot performance

f = MPlot.Figure(8485); clf

ax = subplot(2,1,1);

h = histogram(dL); hold on
h.Normalization = 'probability';
h.BinWidth = 0.02;
h.EdgeColor = 'none';
h.FaceColor = [0 0 0]+.3;

h = histogram(dLhat);
h.Normalization = 'probability';
h.BinWidth = 0.02;
h.EdgeColor = 'none';

MPlot.Axes(ax);
ax.XLim = [-1 1]*0.6;
title('Deviation from human mean');
xlabel('mm');
ylabel('Probability')


ax = subplot(2,1,2);

h = histogram(dA); hold on
h.Normalization = 'probability';
h.BinWidth = 1;
h.EdgeColor = 'none';
h.FaceColor = [0 0 0]+.3;

h = histogram(dAhat);
h.Normalization = 'probability';
h.BinWidth = 1;
h.EdgeColor = 'none';

ax.XLim = [-1 1]*30;
MPlot.Axes(ax);
title('Deviation from human mean');
xlabel('degree');
ylabel('Probability')

MPlot.Paperize(f, 'ColumnsWide', 0.5, 'AspectRatio', 1);
saveFigurePDF(f, fullfile(figDir, 'nn regression'));


