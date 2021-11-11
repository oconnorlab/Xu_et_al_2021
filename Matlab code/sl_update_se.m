%% Recompute and replace all enriched se files in the Analysis folder

tarSearch = MBrowse.Dir2Table(fullfile(SL.SE.GetAnalysisRoot, '**', '* se enriched.mat'));
srcSearch = MBrowse.Dir2Table(fullfile('E:\preprocessed', '**', '* se.mat'));

for i = 1 : height(tarSearch)
    % Match files
    [~, seName] = fileparts(tarSearch.name{i});
    seName = erase(seName, ' enriched');
    ind = contains(srcSearch.name, seName);
    if sum(ind) == 0
        error('Source does not have this se file: %s\n', seName);
    elseif sum(ind) > 1
        error('Found multiple se files at the source: %s\n', seName);
    else
        fprintf('%s => %s\n', srcSearch.name{ind}, tarSearch.name{i});
    end
    
    % Enrich and replace
    load(fullfile(srcSearch.folder{ind}, srcSearch.name{ind}));
    SL.SE.EnrichAll(se);
    save(fullfile(tarSearch.folder{i}, tarSearch.name{i}), 'se');
end


