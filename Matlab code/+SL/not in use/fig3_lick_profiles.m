%% Lick Sequences after Opto Stimulation

datDir = SL.Param.GetAnalysisRoot;

if ~exist('powerName', 'var')
    powerName = "5V";
end
figDir = fullfile(datDir, SL.Param.figDirName, 'Fig3', powerName);


%% Compute lick profiles

% quantNames = {'length', 'angle', 'forceV', 'forceH'};
quantNames = {'length', 'angle'};

cachePath = fullfile(figDir, 'computed lick profiles.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Find and load extracted data
    cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
    cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);
    aaTb = SL.Opto.LoadAnimalAreaTable(cachePaths);
    areaCell = SL.Opto.MergeAnimalAreaTableRows(aaTb);
    clear aaTb
    
    % Label licks
    areaCell = SL.Opto.IndexLicks(areaCell);
    
    % Compute profiles
    pCI = 0;
    labelList = {'initId', 'midId', 'consId'};
    nOpto = numel(labelList);
    nArea = numel(areaCell);
    optoCell = cell(nArea, nOpto);
    ctrlCell = cell(nArea, nOpto);
    clear sInfo
    
    for i = numel(areaCell) : -1 : 1
        lkTb = areaCell{i};
        
        sInfo(i) = lkTb.xlsInfo{1}(1);
        lickObjArray = cellfun(@(x) cat(1,x{:}), lkTb.lickObj, 'Uni', false);
        disp(sInfo(i).area);
        
        for j = 1 : numel(labelList)
            lb = labelList{j};
            if strcmp(lb, 'initId')
                lickIds = 1:5;
            else
                lickIds = -1:3;
            end
            
            disp("Compute by " + lb + " for opto");
            lickObj = lickObjArray{j};
            lickObj = lickObj.SetVfield('lickId', lickObj.GetVfield(lb));
            optoCell{i,j} = SL.Behav.ComputeLickProfile(lickObj, lickIds, quantNames, pCI);
            
            disp("Compute by " + lb + " for ctrl");
            lickObj = lickObjArray{4};
            lickObj = lickObj.SetVfield('lickId', lickObj.GetVfield(lb));
            ctrlCell{i,j} = SL.Behav.ComputeLickProfile(lickObj, lickIds, quantNames, pCI);
        end
    end
    
    save(cachePath, 'quantNames', 'pCI', 'sInfo', 'optoCell', 'ctrlCell');
end


%% Plotting

% Specify plotting parameters
[nArea, nOpto] = size(optoCell);
optoNames = ["init", "mid", "cons"];
areaInd = 1 : nArea;

% quant2plot = quantNames;
quant2plot = {'length', 'angle'};
nQuant = numel(quant2plot);

subOrder = reshape(1:nArea*nQuant, nArea, [])';
errType = 'SD';


% Plot profiles
for j = 1 : nOpto
    f = MPlot.Figure(33200+j); clf
    subIdx = 0;
    for k = areaInd
        for i = 1 : nQuant
            subIdx = subIdx+1;
            ax = subplot(nQuant, nArea, subOrder(subIdx));
            
            SL.BehavFig.LickProfile(optoCell{k,j}, quant2plot{i}, ...
                'ErrorType', errType, ...
                'Color', SL.Param.optoColor);
            
            SL.BehavFig.LickProfile(ctrlCell{k,j}, quant2plot{i}, ...
                'ErrorType', errType, ...
                'Color', [0 0 0]);
            
            SL.OptoFig.FormatLickProfile(ax, quant2plot{i});
            ax.Title.String = sInfo(k).area;
        end
    end
    MPlot.Paperize(f, 'ColumnsWide', 0.4*nArea, 'ColumnsHigh', 0.4);
    saveFigurePDF(f, fullfile(figDir, "lick profiles " + optoNames(j)));
end




