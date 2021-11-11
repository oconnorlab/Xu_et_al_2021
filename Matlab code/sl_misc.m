%% Find sessions with erroneous contact detection

datDir = SL.Param.GetAnalysisRoot;
seSearch = MBrowse.Dir2Table(fullfile(datDir, '**', 'MX1808* se enriched.mat'));
%     "MX180803 2018-11-22" M1
%     "MX180803 2018-11-23" M1
%     "MX180803 2018-11-28" S1BF
%     "MX180804 2018-12-05" VPM/PO
%     "MX180804 2018-12-06" VPM/PO
seSearch = MBrowse.Dir2Table(fullfile(datDir, '**', 'MX1810* se enriched.mat'));
%     "MX181002 2018-12-23" M2ALM
%     "MX181002 2018-12-24" M2ALM
%     "MX181003 2018-10-17" opto 
%     "MX181003 2018-10-18"     ?
seSearch = MBrowse.Dir2Table(fullfile(datDir, '**', 'MX1813* se enriched.mat'));
%     "MX181302 2019-02-01" SC
%     "MX181302 2019-02-10" M1TJ
%     "MX181302 2019-02-12" M1TJ

% 
D = cell(height(seSearch),1);
sessionId = strings(size(D));

for k = 1 : height(seSearch)
    load(fullfile(seSearch.folder{k}, seSearch.name{k}));
    sessionId(k) = SL.SE.GetID(se);
    disp(sessionId(k));
    lickWin = se.GetColumn('behavTime', {'lickOn', 'lickOff'});
    lickDur = cellfun(@(x,y) y-x, lickWin(:,1), lickWin(:,2), 'Uni', false);
    D{k} = cell2mat(lickDur);
end

% 
MPlot.Figure(124); clf

isShort = false(size(D));

for k = 1 : height(seSearch)
    ax = subplot(6,8,k);
    h = histogram(D{k});
    h.BinWidth = 0.005;
    h.BinLimits = [0 0.1];
    h.EdgeColor = 'none';
    title(sessionId(k));
    MPlot.Axes(ax);
    
    isShort(k) = sum(h.BinCounts(1:2)) > 100;
end

sessionId(isShort)


%% Examine correction results of video delay

datDir = SL.Param.GetAnalysisRoot;
xlsSearch = MBrowse.Dir2Table(fullfile(datDir, 'Supporting files', 'MX* video delay.xlsx'));
xlsPaths = fullfile(xlsSearch.folder, xlsSearch.name);

k = 7;
tb = MUtil.ReadXls(xlsPaths{k}, 1, 'ReadVariableNames', false);
tb.trialInd = (1 : height(tb))';

h = histogram(tb.(1));
h.EdgeColor = 'none';
h.BinWidth = 0.002;

ind = find(tb.(1) > 0.05);
tb(ind,:)


%% Update enriching

% Find existing se enriched
datDir = SL.Param.GetAnalysisRoot;
richSearch = MBrowse.Dir2Table(fullfile(datDir, '**', '* se enriched.mat'));
richPaths = fullfile(richSearch.folder, richSearch.name);

% Find all source se
srcSearch = MBrowse.Dir2Table(fullfile('E:\Tongue preprocessed', '**', '* se.mat'));
srcPaths = fullfile(srcSearch.folder, srcSearch.name);
% isInRich = ismember(srcSearch.name, erase(richSearch.name, ' enriched'));

for k = 1 : numel(richPaths)
    % Find corresponding source se
    isSrc = strcmp(erase(richSearch.name{k}, ' enriched'), srcSearch.name);
    load(srcPaths{isSrc});
    
    % Enrich and save
    SL.SE.EnrichAll(se);
    
    % Save enriched
    save(richPaths{k}, 'se');
    
    fprintf('Source:\n%s\n', srcPaths{isSrc});
    fprintf('Target:\n%s\n', richPaths{k});
end


%% Change info in SE

sePaths = MBrowse.Files();
seArray = SL.SE.LoadSession(sePaths, 'Enrich', false);

for k = 1 : numel(seArray)
    se = seArray(k);
    
    % Video paths
    oldRoot = 'F:\Tongue datastore 1';
    newRoot = 'F:\Tongue datastore 1';
    oldPaths = se.userData.hsvInfo.filePaths;
    newPaths = cellfun(@(x) strrep(x, oldRoot, newRoot), oldPaths, 'Uni' ,false);
    se.userData.hsvInfo.filePaths = newPaths;
    
    % Others
    % TBW
    
    save(sePaths{k}, 'se');
end

