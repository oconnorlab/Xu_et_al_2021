%% Linear decoding of behavioral variables

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig7');


%% Load cached decoding results

areaList = {'ALM', 'M1TJ', 'S1TJ'};
decTb = cell(size(areaList));
for a = 1 : numel(areaList)
    cachePath = fullfile(figDir, ['dec cons-seq-cons ' areaList{a}]);
    decTb{a} = load(cachePath);
end
decTb = cat(1, decTb{:});
decTb = struct2table(decTb, 'AsArray', true);


%% Compute bootstrap difference

for k = 1 : height(decTb)
    % Cache variable
    comTb = decTb.comTb{k};
    
    % Reshape traj matrices by trial
    colNames = {'time', 'stim', 'reg', 'pca'};
    for i = 1 : height(comTb)
        nTrials = comTb.numMatched{i};
        for j = 1 : numel(colNames)
            cn = colNames{j};
            val = comTb.(cn){i};
            val = reshape(val, [], sum(nTrials), size(val,2));
            val = permute(val, [2 1 3]);
            comTb.(cn){i} = val;
        end
    end
    
    % Compute distance between trajectories
    meanFun = @(x) MMath.MeanStats(x, 1, 'IsOutlierArgs', {'median'});
    d = squeeze(meanFun(comTb.reg{2}) - meanFun(comTb.reg{1}));
    nboot = 2000;
    bootOps = statset('UseParallel', true);
    m1 = bootstrp(nboot, meanFun, comTb.reg{1}, 'Options', bootOps);
    m2 = bootstrp(nboot, meanFun, comTb.reg{2}, 'Options', bootOps);
    dd = m2 - m1;
    ci = prctile(dd, [.5 99.5], 1);
    ci = reshape(ci, [2 size(d)]);
    ci = permute(ci, [2 3 1]);
    
    decTb.mcomTb{k}.dreg{1} = cat(3, d, d, ci);
end


%% Plot difference

f = MPlot.Figure(2250); clf

cc = lines(numel(areaList));
cc = cc([2 3 1],:);

for a = numel(areaList) : -1 : 1
    % Prepare variables
    sReg = decTb.sReg{a};
    mcomTb = decTb.mcomTb{a};
    mcomTb = SL.PopFig.SetPlotParams(mcomTb);
    mcomTb.color(1,:) = cc(a,:);
    
    % Plot Linear Regression
    SL.PopFig.PlotMeanTraj(mcomTb, sReg, ...
        'Name', 'dreg', ...
        'SubInd', [3 4 5], ...
        'CondInd', 1, ...
        'AxesFun', @SL.Reward.FormatDiffAxes);
end
MPlot.Paperize(f, 'ColumnsWide', .3, 'AspectRatio', 2);
saveFigurePDF(f, fullfile(figDir, "cons proj diff"));


return

%% 

for k = 1 : height(decTb)
    % Cache variable
    comTb = decTb.comTb{k};
    
    % Compute mean traj for each session
    colNames = {'time', 'stim', 'reg', 'pca'};
    for i = 1 : height(comTb)
        nTrials = comTb.numMatched{i};
        for j = 1 : numel(colNames)
            cn = colNames{j};
            val = comTb.(cn){i};
            val = reshape(val, [], sum(nTrials), size(val,2));
            val = mat2cell(val, size(val,1), nTrials, size(val,3))';
            val = cellfun(@(x) squeeze(mean(x,2)), val, 'Uni', false);
            comTb.(cn){i} = val;
        end
    end
    
    % Compute distance between trajectories
    dReg = cellfun(@(x,y) abs(x-y), comTb.reg{1}, comTb.reg{2}, 'Uni', false);
    
    % Average in different windows
    wins = [-Inf 0; 0 0.5; 0.5 1];
    t = comTb.time{1}{1};
    mdReg = cell(1,size(wins,1));
    for i = 1 : size(wins,1)
        ind = t >= wins(i,1) & t < wins(i,2);
        mdReg{i} = cellfun(@(x) median(x(ind,3)), dReg);
    end
    mdReg = cell2mat(mdReg);
    
    decTb.mdReg{k} = mdReg;
end


%% 

f = MPlot.Figure(2457); clf

for k = 1 : height(decTb)
    yy = decTb.mdReg{k};
    yy = rmoutliers(yy, 1);
    yy = yy ./ yy(:,1);
    xx = k + repmat([-.3 0 .3], size(yy,1), 1);
    
    plot(xx', yy', '-', 'Color', [0 0 0 .3]); hold on
end

% MPlot.Paperize(f, 'ColumnsWide', .3, 'AspectRatio', 1.8);
% saveFigurePDF(f, fullfile(figDir, "projections cons " + decTb.areaName{a}));




