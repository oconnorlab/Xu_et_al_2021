% Average lick and touch probabilities as a function of time

datDir = SL.Data.analysisRoot;

if ~exist('powerName', 'var')
    powerName = '5V';
end
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig3', powerName);


%% Load data

dataSource = SL.Data.FindSessions(['fig3_extract_data_' powerName]);
seAll = SL.SE.LoadSession(dataSource.path, 'UserFunc', @(x) x.RemoveTable('adc', 'hsv'));
xlsAll = MBrowse.ReadXls(SL.Data.metadataSheet, 'Opto');


%% Extract and preprocess data

% Determine animals and areas
sessionAnimalIds = arrayfun(@(x) x.userData.sessionInfo.animalId, seAll, 'Uni', false);
animalNames = unique(sessionAnimalIds);
if ~exist('areaNames', 'var')
    areaNames = {'S1TJ', 'ALM', 'S1BF', 'M1B', 'S1Tr'};
end

% Iterate through animals
for a = 1 : numel(animalNames)
    % Determine caching location
    cacheName = "aaTb " + animalNames{a} + ".mat";
    cachePath = fullfile(figDir, cacheName);
    if exist(cachePath, 'file')
        warning('%s already exists can will not be generated again', cacheName);
        continue
    end
    
    % Find the subset of data
    seAni = seAll(strcmp(sessionAnimalIds, animalNames{a})).Duplicate();
    xlsAni = SL.SE.AddXlsInfo2SE(seAni, xlsAll);
    
    % Processing parameters
    ops = SL.Param.Transform;
    ops.isSpkRate = false;
    ops.isStdLickRange = true;
    cond2select = cell2table({ ...
        '123456', -1; ...
        '543210', -1; ...
        '123456', 0; ...
        '543210', 0; ...
        '123456', 1; ...
        '543210', 1; ...
        '123456', 2; ...
        '543210', 2; ...
        }, 'VariableNames', ops.conditionVars);
    cond2select.seqId = SL.Param.CategorizeSeqId(cond2select.seqId);
    cond2merge = table([-1 0 1 2]', 'VariableNames', ops.conditionVars(2));
    
    % Group data
    aaTb = cell(size(areaNames));
    for i = 1 : numel(areaNames)
        % Find sessions for the given area
        seInd = find(strcmp(xlsAni.area, areaNames{i}));
        if isempty(seInd)
            warning('%s: no session can be found for %s', animalNames{a}, areaNames{i});
            continue
        end
        
        % Make and concatenate seTbs
        seTbs = cell(numel(seInd), 1);
        for j = 1 : numel(seInd)
            seTb = SL.SE.Transform(seAni(seInd(j)), ops);
            seTb = SL.SE.CombineConditions(cond2select, seTb); % forget why this line is necessary
            seTbs{j} = seTb;
        end
        seTbCat = cat(1, seTbs{:});
        
        % Merge sessions of the same condition
        seTbCat.seqId = [];
        seTbMer = SL.SE.CombineConditions(cond2merge, seTbCat);
        seTbMer.se = cellfun(@(x) x(1).Merge(x(2:end)), seTbMer.se);
        seTbMer.numTrial = cellfun(@sum, seTbMer.numTrial);
        
        % Extract trigger times and Lick objects (true for inverting)
        lkTb = SL.Behav.ExtractLickData(seTbMer, true);
        
        % Put non-opto condition to the end (for backward compatibility)
        lkTb = lkTb([2 3 4 1],:);
        
        aaTb{i} = lkTb;
    end
    aaTb = cell2table(aaTb, 'VariableNames', areaNames, 'RowNames', animalNames(a));
    
    save(cachePath, 'aaTb', 'ops');
end

