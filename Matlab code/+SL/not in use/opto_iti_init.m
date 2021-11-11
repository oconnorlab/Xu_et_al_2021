%% Effects on sequence initiation after photoinhibition during ITI

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'temp');
if ~exist('figDir', 'dir')
    mkdir(figDir);
end


%% Load data

dataSource = SL.Data.FindSessions('fig3_extract_data_5V');
seArray = SL.SE.LoadSession(dataSource.path, 'UserFunc', @(x) x.RemoveTable('adc', 'hsv'));

xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Opto');


%% Extract and preprocess data

% Determine animals and areas
animalNames = unique(dataSource.animalId);
areaNames = {'ALM', 'S1TJ', 'S1BF', 'M1B', 'S1Tr'};

% Iterate through animals
for a = 1 : numel(animalNames)
    % Determine caching location
    cacheName = "extracted data " + animalNames{a} + ".mat";
    cachePath = fullfile(figDir, cacheName);
    if exist(cachePath, 'file')
        warning('%s already exists can will not be generated again', cacheName);
        continue
    end
    
    % Find the subset of data
    seSubArray = seArray(strcmp(dataSource.animalId, animalNames{a})).Duplicate;
    xlsSubTb = SL.SE.AddXlsInfo2SE(seSubArray, xlsTb);
    
    % Exclude the first and the last trial
    ops = SL.Param.Transform;
    arrayfun(@(x) SL.Behav.ExcludeTrials(x, ops), seSubArray);
    
    % Group data
    sCell = cell(size(areaNames));
    for i = 1 : numel(areaNames)
        % Find sessions for the given area
        seInd = find(strcmp(xlsSubTb.area, areaNames{i}));
        if isempty(seInd)
            warning('%s: no session can be found for %s', animalNames{a}, areaNames{i});
            continue
        end
        se = Merge(seSubArray(seInd));
        
        % Extract data
        s = struct;
        [s.ind, s.lickObj] = SL.Opto.ExtractInitData(se);
        
        sCell{i} = s;
    end
    areaTb = cell2table(sCell, 'VariableNames', areaNames, 'RowNames', animalNames(a));
    
    save(cachePath, 'areaTb');
end


%% Find and load data extracted and cached by SL.fig6_behav_stats

cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "extracted data *.mat"));
cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);

areaCell = cell(size(cachePaths));
for i = 1 : numel(cachePaths)
    load(cachePaths{i});
    areaCell{i} = areaTb;
end
areaTb = vertcat(areaCell{:});


%% 

% Histogram parameters
lickId = (1 : 5)';
aEdges = -60:5:60;
quantTb = table();
quantTb.name = {'angle'}';
quantTb.edges = {aEdges}';

ang = zeros(numel(aEdges)-1, numel(lickId), width(areaTb), height(areaTb));
for i = 1 : height(areaTb)
    for j = 1 : width(areaTb)
        % Get licks from trials with no opto
        s = areaTb{i,j};
        licks = cat(1, s.lickObj{s.ind.none});
        
        % Compute histograms
        histTb = SL.Behav.ComputeLickStats(licks, quantTb, lickId);
        ang(:,:,j,i) = histTb.angle';
    end
end
[angMean, angSD] = MMath.MeanStats(ang, 4);


%% 

% Histogram parameters
lickId = (1 : 3)';
aEdges = -60:5:60;
quantTb = table();
quantTb.name = {'angle'}';
quantTb.edges = {aEdges}';

% Preallocation
angOpto = zeros(numel(aEdges)-1, numel(lickId), width(areaTb), height(areaTb));
angCtrl = angOpto;

for i = 1 : height(areaTb)
    for j = 1 : width(areaTb)
        % Cache variable
        s = areaTb{i,j};
        
        % Label licks
        for k = 1 : numel(s.lickObj)
            lk = s.lickObj{i};
            
            % From trial start
            lk = lk.SetVfield('startId', (1:numel(lk))');
            
            % From 2s offset
            lb = NaN(size(lk));
            i2s = find(lk > 2 & lk < 3, 1);
            if ~isempty(i2s)% && i2s == 1
                lb(i2s:end) = i2s : numel(lk);
            end
            lk = lk.SetVfield('postId', lb);
            
            s.lickObj{i} = lk;
        end
        
        % Get licks from trials with no opto
        lkCtrl = cat(1, s.lickObj{s.ind.none});
        lkCtrl = lkCtrl.SetVfield('lickId', lkCtrl.GetVfield('startId'));
        
        % Get licks after opto init
        lkOpto = cat(1, s.lickObj{s.ind.init});
        lkOpto = lkOpto.SetVfield('lickId', lkOpto.GetVfield('postId'));
        
        % Compute histograms
        histTb = SL.Behav.ComputeLickStats(lkCtrl, quantTb, lickId);
        angCtrl(:,:,j,i) = histTb.angle';
        histTb = SL.Behav.ComputeLickStats(lkOpto, quantTb, lickId);
        angOpto(:,:,j,i) = histTb.angle';
    end
end

% Average across animals
[angCtrlMean, angCtrlSD] = MMath.MeanStats(angCtrl, 4);
[angOptoMean, angOptoSD] = MMath.MeanStats(angOpto, 4);


%% 

f = MPlot.Figure(445); clf

[nBin, nId, nArea, nMice] = size(ang);
cc = lines(nArea);

hold on
for i = 1 : nArea
    for j = 1 : nMice
        MPlot.Violin(lickId+i*.15, aEdges(ones(1,nId),:)', ang(:,:,i,j)*.4, ...
            'Percentiles', 50, 'Color', cc(i,:));
    end
end


%%

f = MPlot.Figure(446); clf

[nBin, nId, nArea, nMice] = size(ang);
cc = lines(nArea);

hold on
for i = 1 : nArea
    MPlot.Violin(lickId+i*.15, aEdges(ones(1,nId),:)', (angMean(:,:,i)+angSD(:,:,i))*.5, ...
        'Color', [0 0 0 .15], 'Style', 'contour');
    MPlot.Violin(lickId+i*.15, aEdges(ones(1,nId),:)', angMean(:,:,i)*.5, ...
        'Percentiles', [25 50 75], 'Color', cc(i,:), 'Style', 'contour');
end
ylim(aEdges([1 end]));


%%

f = MPlot.Figure(446); clf

[nBin, nId, nArea, nMice] = size(angOpto);
r = 2;

hold on
for i = 1 : 1%nArea
    MPlot.Violin((i-1)*4+lickId-.2, aEdges(ones(1,nId),:)', angCtrlMean(:,:,i)*r, ...
        'Percentiles', [25 50 75], 'Color', [0 0 0]);
    MPlot.Violin((i-1)*4+lickId+.2, aEdges(ones(1,nId),:)', angOptoMean(:,:,i)*r, ...
        'Percentiles', [25 50 75], 'Color', SL.Param.optoColor);
end
ax = MPlot.Axes(gca);
% ax.XLim = [0 nId+1];
ax.YLim = aEdges([1 end]);

