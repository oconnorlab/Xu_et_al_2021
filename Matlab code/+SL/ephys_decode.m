%% Linear decoding of behavioral variables

% Choose parameters based on analysis
switch analysisName
    case 'fig5_seq_coding'
        figName = 'Fig5';
        datName = 'seq'; % data to use
        mdlName = 'seq'; % model to use
        winName = 'seq'; % time window to decode
        areaList = {'S1TJ', 'M1TJ', 'ALM', 'S1BF', 'M1B', 'S1L'};
        
    case 'fig6_iti_coding'
        figName = 'Fig6';
        datName = 'iti'; % data to use
        mdlName = 'iti'; % model to use
        winName = 'iti'; % time window to decode
        areaList = {'S1TJ', 'M1TJ', 'ALM', 'S1BF'};
        
    case 'fig6_seq_coding'
        figName = 'Fig6';
        datName = 'seq'; % data to use
        mdlName = 'iti'; % model to use
        winName = 'seq'; % time window to decode
        areaList = {'ALM'};
        
    case 'fig7_cons_coding'
        figName = 'Fig7';
        datName = 'cons'; % data to use
        mdlName = 'seq';  % model to use
        winName = 'cons'; % time window to decode
        areaList = {'S1TJ', 'M1TJ', 'ALM'};
        
    case 'figZ_seq_coding'
        figName = 'FigZ';
        datName = 'seq_zz'; % data to use
        mdlName = 'seq_zz'; % model to use
        winName = 'seq_zz'; % time window to decode
        areaList = {'ZZ'};
        
    otherwise
        error('''%s'' is not a valid analysisName', analysisName);
end


%% 

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, figName);

isOverwrite = false;

for a = 1 : numel(areaList)
    % Find files
    areaName = areaList{a};
    cachePath = fullfile(figDir, ['dec ' datName '-' mdlName '-' winName ' ' areaName '.mat']);
    if exist(cachePath, 'file') && ~isOverwrite
        warning('Cached file for %s already exists and will not be overwritten', areaName);
        continue
    end
    
    disp(areaName);
    areaDirName = ['Data ephys ' areaName];
    seTbSearch = MBrowse.Dir2Table(fullfile(datDir, areaDirName, [datName ' dt_0'], 'seTb *.mat'));
    mdlsSearch = MBrowse.Dir2Table(fullfile(datDir, areaDirName, [mdlName ' dt_0'], 'lm *.mat'));
    
    % Load data
    seTbArray = cell(height(seTbSearch),1);
    for i = 1 : height(seTbSearch)
        load(fullfile(seTbSearch.folder{i}, seTbSearch.name{i}));
        seTbArray{i} = seTb;
    end
    
    mdlsArray = cell(height(mdlsSearch),1);
    for i = 1 : height(mdlsSearch)
        load(fullfile(mdlsSearch.folder{i}, mdlsSearch.name{i}));
        mdlsArray{i} = mdls;
    end
    
    % Set up shared or default options
    ops = mdlsArray{1}.ops;
    ops.conditionTb = cell2table({ ...
        '123456', -1; ...
        '543210', -1; ...
        '1231456', -1; ...
        '5435210', -1; ...
        '123432101234', -1; ...
        '321012343210', -1; ...
        }, 'VariableNames', ops.conditionVars);
    ops.conditionTb.seqId = SL.Param.CategorizeSeqId(ops.conditionTb.seqId);
    
    % Set up analysis-specific options
    switch winName
        case 'seq'
            ops.rsWin = [-.5 .8];
        case 'iti'
            ops.rsWin = [-1.3 0];
        case 'cons'
            ops.rsWin = [-.3 1];
        case 'seq_zz'
            ops.rsWin = [-1 1];
        otherwise
            error('%s is not a valid winName', winName);
    end
    
    % Decoding
    [sReg, comTb, mcomTb] = SL.Pop.LinearDecoding(seTbArray, mdlsArray, ops);
    
    % Cache results
    save(cachePath, 'areaName', 'sReg', 'comTb', 'mcomTb');
end

