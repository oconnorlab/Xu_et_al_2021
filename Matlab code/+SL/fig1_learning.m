%% Learning Curves of Normal Sequences

rootDir = SL.Data.analysisRoot;
figDir = fullfile(rootDir, SL.Data.figDirName, 'Fig1');


%% Find and copy log files

% Find animals of interest
tb = SL.Data.FindSessions('fig1_learning');
tb = SL.Data.Session2AnimalTable(tb);

if ~exist(SL.Data.rawRoot, 'dir')
    warning('Source directory SL.Data.rawRoot does not exist or cannot be accessed');
else
    for i = 1 : height(tb)
        % Search for SatellitesViewer logs
        animalId = tb.animalId{i};
        pathKey = fullfile(SL.Data.rawRoot, '*', 'SatellitesViewer', [animalId '*.txt']);
        logFileInfo = MBrowse.Dir2Table(pathKey);
        assert(~isempty(logFileInfo), 'No log file was found for %s', animalId);
        
        % Make folder
        animalDir = fullfile(rootDir, 'Data learning', animalId);
        if ~exist(animalDir, 'dir')
            mkdir(animalDir);
        end
        
        % Copy SatellitesViewer logs into analysis
        srcPaths = fullfile(logFileInfo.folder, logFileInfo.name);
        dstPaths = fullfile(animalDir, logFileInfo.name);
        for j = 1 : numel(srcPaths)
            copyfile(srcPaths{j}, dstPaths{j});
        end
        tb.logNames{i} = logFileInfo.name;
        tb.logPaths{i} = dstPaths;
    end
end


%% Generate and cache seArray

for i = 1 : height(tb)
    % Find log files
    animalId = tb.animalId{i};
    pathKey = fullfile(rootDir, 'Data learning', animalId, '*.txt');
    txtFileInfo = MBrowse.Dir2Table(pathKey);
    if isempty(txtFileInfo)
        warning('No SatellitesViewer log file was found for %s', animalId);
        continue
    end
    txtPaths = fullfile(txtFileInfo.folder, txtFileInfo.name);
    
    % Make and cache seArray
    seArrayPath = fullfile(rootDir, 'Data learning', [animalId ' seArray.mat']);
    if exist(seArrayPath, 'file')
        warning('seArray for %s already exists and will not be overwritten', animalId);
        continue
    end
    seArray = SL.SE.LoadSession(txtPaths, 'Enrich', true);
    save(seArrayPath, 'seArray');
end


%% Compute learning curves

cachePath = fullfile(figDir, 'computed learning curves.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Load and preprocess seArrays
    seArraySearch = MBrowse.Dir2Table(fullfile(rootDir, 'Data learning', '* seArray.mat'));
    seArrayPaths = fullfile(seArraySearch.folder, seArraySearch.name);
    seArrays = cell(size(seArrayPaths));
    parfor i = 1 : height(seArraySearch)
        sTrials = load(seArrayPaths{i});
        seArray = sTrials.seArray(1:10); % the first 10 sessions is enough
        for j = 1 : numel(seArray)
            % Add positional command data
            SL.SE.AddPositionalCommands(seArray(j));
            
            % Exclude the first and the last trial
            seArray(j).RemoveEpochs([1 seArray(j).numEpochs]);
        end
        seArrays{i} = seArray;
    end
    
    % Compute learning curves
    lcOps.maxTrials = 1500;
    lcOps.binSize = 100;
    lcOps.transRange = 4:5;
    lcOps.analysisNames = {'numTrials', 'posParam', 'firstDrive', 'ITI', 'seqDur_S'};
    
    lcCell = cell(size(seArrays));
    parfor i = 1 : numel(lcCell)
        disp(i);
        lcCell{i} = SL.Learn.ComputeLearningCurves(seArrays{i}, lcOps);
    end
    
    save(cachePath, 'lcCell');
end


%% Prepare data for plotting example consecutive trials across learning

seArraySearch = MBrowse.Dir2Table(fullfile(rootDir, 'Data learning', '* seArray.mat'));
k = find(startsWith(seArraySearch.name, 'MX170903'));
load(fullfile(seArraySearch.folder{k}, seArraySearch.name{k}));
seArray = seArray(1:10); % the first 10 sessions is enough

for j = 1 : numel(seArray)
    % Exclude the first and the last trial in each session
    seArray(j).RemoveEpochs([1 seArray(j).numEpochs]);
end

% Concatenate sessions
se = seArray(1).Merge(seArray(2:end));

% Extract data
sTrials = SL.Learn.PrepareConsecutiveTrialsData(se);


%% Plot example consecutive trials across learning

% Set trial starts and the duration of time window
trialStarts = [98 645 1300];
dur = 120;

f = MPlot.Figure(433); clf
for i = 1 : numel(trialStarts)
    subplot(numel(trialStarts),1,i); cla
    SL.Learn.PlotConsecutiveTrials(sTrials, trialStarts(i), dur);
end
MPlot.Paperize(f, 'ColumnsWide', 2, 'ColumnsHigh', .5);
saveFigurePDF(f, fullfile(figDir, 'example trials in learning'));


%% Plot learning curves

f = MPlot.Figure(455); clf

ss = cat(1, lcCell{:});
x = ss(1).binCenters;
cEach = repmat([0 0 0 .2], [numel(ss) 1]);

% Reaction Time
ax = subplot(2,2,1);
for i = 1 : length(ss)
    y = ss(i).firstDrive.median * 1e3;
    plot(x, y, '-', 'Color', cEach(i,:)); hold on
%     text(x(end), y(end), num2str(i));
    if i == k
        SL.Learn.HighlightExamples(x, y, trialStarts);
    end
end
yy = cell2mat(arrayfun(@(x) x.firstDrive.median, ss, 'Uni', false)');
yMean = nanmean(yy, 2) * 1e3;
plot(x, yMean, 'k-', 'LineWidth', 1);
ax.YScale = 'log';
ax.YLim = [1e2 1.5e4];
ax.YTick = [1e2 1e3 1e4];
ax.YTickLabel = ax.YTick ./ 1e3;
SL.Learn.FormatLearningCurveAxes(ax, x);
ylabel('Second');
title('Time to first touch');

% Instantaneous rate of drive licks
ax = subplot(2,2,2);
for i = 1 : length(ss)
    y = 6./ss(i).seqDur_S.median;
    plot(x, y, '-', 'Color', cEach(i,:)); hold on
%     text(x(1), y(1), num2str(i));
    if i == k
        SL.Learn.HighlightExamples(x, y, trialStarts);
    end
end
yy = cell2mat(arrayfun(@(x) x.seqDur_S.median, ss, 'Uni', false)');
yy = 6./yy;
yMean = nanmean(yy, 2);
plot(x, yMean, 'k-', 'LineWidth', 1);
ax.YLim = [0 8];
ax.YTick = 0:2:8;
SL.Learn.FormatLearningCurveAxes(ax, x);
ylabel('Positions/s');
title('Sequence speed');

% Positional parameters
ax = subplot(2,2,3);

for i = 1 : length(ss)
    y = ss(i).posParam.mean(:,1)/1e3;
    plot(x, y, '-', 'Color', cEach(i,:)); hold on
end
yy = cell2mat(arrayfun(@(x) x.posParam.mean(:,1), ss, 'Uni', false)');
yy = yy/1e3;
yMean = nanmean(yy, 2);
plot(x, yMean, 'k-', 'LineWidth', 1);
ax.YLim = [3 5.2];
SL.Learn.FormatLearningCurveAxes(ax, x);
ylabel('mm');
title('AP distance to Mid');

ax = subplot(2,2,4);

for i = 1 : length(ss)
    y = ss(i).posParam.mean(:,2)*2/1e3;
    plot(x, y, '-', 'Color', cEach(i,:)); hold on
end
yy = cell2mat(arrayfun(@(x) x.posParam.mean(:,2), ss, 'Uni', false)');
yy = yy*2/1e3;
yMean = nanmean(yy, 2);
plot(x, yMean, 'k-', 'LineWidth', 1);
ax.YLim = [3 7.5];
SL.Learn.FormatLearningCurveAxes(ax, x);
ylabel('mm');
title('Distance from L3 to R3');

MPlot.Paperize(f, 'ColumnsWide', .75, 'AspectRatio', .75);
saveFigurePDF(f, fullfile(figDir, 'learning curves'));

