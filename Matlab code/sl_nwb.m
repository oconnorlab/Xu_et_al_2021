%% Find files

nwbDir = 'C:\Users\yaxig\Dropbox (oconnorlab)\oconnorlab Team Folder\projects\NWB\SeqLick';

sePaths = MBrowse.Files(nwbDir);

ephyTb = MBrowse.ReadXls(SL.Param.metadataSheet, 'Si');
optoTb = MBrowse.ReadXls(SL.Param.metadataSheet, 'Opto');


%% Add metadata from 'SeqLick Master.xlsx' to se

for i = 1 : numel(sePaths)
    % Load se
    load(sePaths{i})
    
    % Add metadata
    SL.SE.AddXlsInfo2SE(se, ephyTb);
    SL.SE.AddXlsInfo2SE(se, optoTb);
    
    % Save modified se
    save(sePaths{i}, 'se');
end


