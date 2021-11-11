%% Find and collect files

% Find animals that contribute to analysis
datDir = SL.Util.GetAnalysisRoot;
seSearch = [ ...
    MUtil.Dir2Table(fullfile(datDir, 'Data Ephys *', '* se enriched.mat')); ...
    MUtil.Dir2Table(fullfile(datDir, 'Data Opto VGAT-CRE Ai32 2s *', '* se enriched.mat')) ...
    ];
animalNames = regexp(seSearch.name, '^[A-Z]{2}\d+', 'match');
animalNames = cat(1, animalNames{:});
animalNames = unique(animalNames);
animalNames = string(animalNames);

% Exclude animals that had unconventional shaping
animalNames(ismember(animalNames, ["MX180202", "MX180203", "MX180401", "MX180501"])) = [];

% Search for SatellitesViewer logs
rawDataRoot = 'F:\Tongue datastore 1';
keyPaths = fullfile(rawDataRoot, '*', 'SatellitesViewer', animalNames + '*.txt');
animalSearch = arrayfun(@MUtil.Dir2Table, keyPaths, 'Uni' ,false);

% Copy logs together
for i = 1 : numel(animalSearch)
    if isempty(animalSearch{i})
        continue;
    end
    srcPaths = string(fullfile(animalSearch{i}.folder, animalSearch{i}.name));  
    animalDir = fullfile(datDir, 'Data learning', animalNames(i));
    dstPaths = fullfile(animalDir, animalSearch{i}.name);
    if ~exist(animalDir, 'dir')
        mkdir(animalDir);
    end
    for j = 1 : numel(srcPaths)
        copyfile(srcPaths(j), dstPaths(j));
    end
end


%% Cache seArray

% Search for SatellitesViewer logs
keyPaths = fullfile(datDir, 'Data learning', animalNames, '*.txt');
animalSearch = arrayfun(@MUtil.Dir2Table, keyPaths, 'Uni' ,false);

% 
for i = 1 : numel(animalSearch)
    txtPaths = fullfile(animalSearch{i}.folder, animalSearch{i}.name);
    seArray = SL.Util.LoadSession(txtPaths, 'Enrich', true);
    cachePath = fullfile(datDir, 'Data learning', animalNames(i) + ' seArray.mat');
    save(cachePath, 'seArray');
end


