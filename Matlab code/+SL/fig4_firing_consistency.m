%% Functional clustering of unit

% Find se files
figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig4');
dataSource = SL.Data.FindSessions('fig4_nnmf');
sePaths = dataSource.path;

% Load metadata
xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');

% Load previosuly computed unit quality info and select sessions for current analysis
s = load(fullfile(figDir, 'computed uqTbCell.mat'));
I = ismember(s.dataSource.sessionId, dataSource.sessionId);
uqTbCell = s.uqTbCell(I);


%% Compute PETHs

cachePath = fullfile(figDir, 'computed urTbCell 2-fold.mat');

if exist(cachePath, 'file')
    % Load previously computed data
    load(cachePath);
else
    % Compute new
    urTbCell1 = cell(size(sePaths));
    urTbCell2 = cell(size(sePaths));
    errCell = cell(size(sePaths));
    
    parfor i = 1 : numel(sePaths)
        % Load SE and add metadata from spreadsheet
        se = SL.SE.LoadSession(sePaths{i}, 'UserFunc', @(x) x.RemoveTable('LFP', 'adc', 'hsv'));
        SL.SE.AddXlsInfo2SE(se, xlsTb);
        disp(SL.SE.GetID(se));
        
        % Computing spike rates, morphing, reslicing, trial exclusion
        ops = SL.Param.Transform;
        ops = SL.Param.Resample(ops);
        ops.isMorph = true;
        ops.tReslice = -1;
        ops.maxReactionTime = 1;
        ops.maxEndTime = 8;
        SL.SE.Transform(se, ops);
        
        % Skip processed steps in later transformation
        ops.isSpkRate = false;
        ops.isMorph = false;
        ops.tReslice = 0;
        
        % Matching
        alignTypes = {'init', 'mid', 'term'};
        seTbCat = cell(size(alignTypes));
        for j = 1 : numel(alignTypes)
            disp(alignTypes{j});
            
            % Complete matching options
            ops.alignType = alignTypes{j};
            ops = SL.Param.FillMatchOptions(ops);
            
            % Transform SE
            seCopy = se.Duplicate;
            seTb = SL.SE.Transform(seCopy, ops);
            
            % Select conditions
            conds = cell2table({ ...
                '123456', -1; ...
                '543210', -1; ...
                }, 'VariableNames', ops.conditionVars);
            conds.seqId = SL.Param.CategorizeSeqId(conds.seqId);
            seTbCat{j} = SL.SE.CombineConditions(conds, seTb, 'Uni', true);
        end
        seTbCat = cat(1, seTbCat{:});
        
        % Compute unit PETH table
        nFold = 2;
        sePar = SL.SE.PartitionTrials(seTbCat.se, nFold);
        unitPETH = cell(nFold,1);
        for j = 1 : nFold
            unitPETH{j} = SL.Unit.UnitPETH(sePar(:,j));
            unitPETH{j}.unitNum = [];
        end
        unitInfo = SL.Unit.UnitInfo(se);
        urTbCell1{i} = [unitInfo unitPETH{1}];
        urTbCell2{i} = [unitInfo unitPETH{2}];
        
        % Bootstrap error
        nBoot = 200;
        bootErr = zeros(height(unitInfo), nBoot);
        for n = 1 : nBoot
            sePar = SL.SE.PartitionTrials(seTbCat.se, nFold);
            unitPETH = cell(nFold,1);
            for j = 1 : nFold
                unitPETH{j} = SL.Unit.UnitPETH(sePar(:,j));
            end
            [~, bootErr(:,n)] = SL.Unit.DiffPETH(unitPETH{:});
        end
        errCell{i} = bootErr;
    end
    
    save(cachePath, 'dataSource', 'urTbCell1', 'urTbCell2', 'errCell');
end


%% NNMF clustering

uqTb = vertcat(uqTbCell{:});
urTb1 = vertcat(urTbCell1{:});
urTb2 = vertcat(urTbCell2{:});
bootErr = vertcat(errCell{:});

% Group S1FL into S1L
urTb1.areaName = strrep(urTb1.areaName, 'S1FL', 'S1L');
urTb2.areaName = strrep(urTb2.areaName, 'S1FL', 'S1L');

% Use the maximum peak spike rate 
urTb1.peakSpkRate = max(urTb1.peakSpkRate, urTb2.peakSpkRate);
urTb2.peakSpkRate = urTb1.peakSpkRate;

% Select units
isActive = urTb1.peakSpkRate >= 10 | urTb2.peakSpkRate >= 10; % Hz
isSingle = uqTb.FA <= SL.Param.maxFA & uqTb.contam <= SL.Param.maxContam;
isInAOI = ismember(urTb1.areaName, {'ALM', 'M1TJ', 'S1TJ', 'S1BF', 'M1B', 'S1L'});
I = isActive & isSingle & isInAOI;
urTb1 = urTb1(I,:);
urTb2 = urTb2(I,:);
bootErr = bootErr(I,:);

% Compute clusters
nComp = 13;
[urTb1, sClust1] = SL.Unit.NNMFExpress(urTb1, nComp);

% Apply cluster info to the second fold
urTb2.clustId = urTb1.clustId;
urTb2.clustScore = urTb1.clustScore;

% Compute difference table
diffTb = SL.Unit.DiffPETH(urTb1, urTb2);
diffTb.rmse = mean(bootErr, 2);


%% Boxplots of RMSE

areaNames = {'S1TJ', 'M1TJ', 'ALM', 'S1BF'};
isArea = ismember(diffTb.areaName, areaNames);
fprintf('%i neurons are included in the boxplots\n', sum(isArea));

subTb = diffTb(isArea,:);
subTb.areaName = categorical(subTb.areaName, areaNames, 'Ordinal', true);
[subTb, I] = sortrows(subTb, {'areaName'});

f = MPlot.Figure(40); clf
boxplot(subTb.rmse, subTb.areaName);
ax = MPlot.Axes(gca);
ax.YLim = [0 1];
ax.YLabel.String = 'RMSE (frac. of peak spk rate)';
ax.Title.String = 'Uncertainty of PETHs';
MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', .4);
MPlot.SavePDF(f, fullfile(figDir, "PETH uncertainty"));


return
%% Plot Heatmaps

areaNames = {'S1TJ', 'M1TJ', 'ALM', 'S1BF'};

% First fold
for i = 1 : numel(areaNames)
    isArea = strcmp(areaNames{i}, urTb1.areaName);
    subTb = sortrows(urTb1(isArea,:), {'clustId', 'clustScore'});
    
    f = MPlot.Figure(10+i); clf
    SL.UnitFig.PlotHeatmap(subTb, 1:nComp);
    MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', .5);
%     MPlot.SavePDF(f, fullfile(figDir, "PETH heatmap fold1 " + areaNames{i}));
end

% Second fold
for i = 1 : numel(areaNames)
    isArea = strcmp(areaNames{i}, urTb2.areaName);
    subTb = sortrows(urTb2(isArea,:), {'clustId', 'clustScore'});
    
    f = MPlot.Figure(20+i); clf
    SL.UnitFig.PlotHeatmap(subTb, 1:nComp);
    MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', .5);
%     MPlot.SavePDF(f, fullfile(figDir, "PETH heatmap fold2 " + areaNames{i}));
end

% Absolute error between first and second
for i = 1 : numel(areaNames)
    isArea = strcmp(areaNames{i}, diffTb.areaName);
    subTb = sortrows(diffTb(isArea,:), {'clustId', 'clustScore'});
    
    f = MPlot.Figure(30+i); clf
    SL.UnitFig.PlotHeatmap(subTb, 1:nComp);
    MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', .5);
%     MPlot.SavePDF(f, fullfile(figDir, "PETH heatmap diff " + areaNames{i}));
end

