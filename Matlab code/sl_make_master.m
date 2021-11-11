%% Find files based on SatellitesViewer files

% Choose a group folder
rootDir = 'F:\SeqLick datastore 1';

rootInfo = MBrowse.Dir2Table(rootDir);
rootInfo(~rootInfo.isdir,:) = [];
rootInfo(1:2,:) = [];
groupDirs = cellfun(@fullfile, rootInfo.folder, rootInfo.name, 'Uni', false);

selectedIdx = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'ListSize', [300 400], ...
    'ListString', groupDirs);

if ~isempty(selectedIdx)
    groupDir = groupDirs{selectedIdx};
else
    groupDir = MBrowse.Folder(rootDir, 'Select the group folder');
end

if ~groupDir
    return;
end

clear groupDirs selectedIdx


% Find content of the group folder and pertinent subforders
groupDirInfo = MBrowse.Dir2Table(groupDir);
satDirInfo = [];
intanDirInfo = [];
hsvDirInfo = [];
camDirInfo = [];

for i = 1 : height(groupDirInfo)
    switch groupDirInfo.name{i}
        case 'SatellitesViewer'
            satDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}, '*.txt'));
        case 'Intan'
            intanDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            intanDirInfo(1:2,:) = [];
        case 'Video'
            hsvDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            hsvDirInfo(1:2,:) = [];
        case 'Camera'
            camDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            camDirInfo(1:2,:) = [];
    end
end


% Find all data files for each session
dataFileTb = table();

for i = height(satDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    satNameParts = strsplit(satDirInfo.name{i}, {' ', '.'});
    animalId = satNameParts{1};
    sessionDatetime = datetime([satNameParts{2} ' ' satNameParts{3}], ...
        'InputFormat','yyyy-MM-dd HH-mm-ss', ...
        'Format', 'yyyy-MM-dd HH:mm:ss');
    subId = '';
    if numel(satNameParts) > 4
        subId = satNameParts{4};
    end
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add SatellitesViewer log file path
    dataFileTb.satPath{i} = fullfile(satDirInfo.folder{i}, satDirInfo.name{i});
    
    % Find Intan files
    dataFileTb.intanPaths{i} = [];
    if ~isempty(intanDirInfo)
        queryStr = ['^' animalId '.+' datestr(sessionDatetime, 'yymmdd') '.*' subId];
        isHit = ~cellfun(@isempty, regexpi(intanDirInfo.name, queryStr));
        if any(isHit)
            fileInfo = MBrowse.Dir2Table(fullfile(intanDirInfo.folder{isHit}, intanDirInfo.name{isHit}, '*.rhd'));
            if ~isempty(fileInfo)
                fileInfo = sortrows(fileInfo, 'datenum');
                dataFileTb.intanPaths{i} = cellfun(@(x,y) fullfile(x,y), fileInfo.folder, fileInfo.name, 'Uni', false);
            end
        end
    end
    
    % Find high-speed video files
    dataFileTb.hsvPaths{i} = [];
    if ~isempty(hsvDirInfo)
        queryStr = ['^' animalId '.+' datestr(sessionDatetime, 'yymmdd') '.*' subId];
        isHit = ~cellfun(@isempty, regexpi(hsvDirInfo.name, queryStr));
        if any(isHit)
            fileInfo = MBrowse.Dir2Table(fullfile(hsvDirInfo.folder{isHit}, hsvDirInfo.name{isHit}, '*.avi'));
            if ~isempty(fileInfo)
                fileInfo = sortrows(fileInfo, 'datenum');
                dataFileTb.hsvPaths{i} = cellfun(@(x,y) fullfile(x,y), fileInfo.folder, fileInfo.name, 'Uni', false);
            end
        end
    end
    
    % Find standard video files
    dataFileTb.camPaths{i} = [];
    if ~isempty(camDirInfo)
        queryStr = ['^' animalId '.+' datestr(sessionDatetime, 'yymmdd') '.*' subId];
        isHit = ~cellfun(@isempty, regexpi(camDirInfo.name, queryStr));
        if any(isHit)
            fileInfo = MBrowse.Dir2Table(fullfile(camDirInfo.folder{isHit}, camDirInfo.name{isHit}, '*.avi'));
            if ~isempty(fileInfo)
                fileInfo = sortrows(fileInfo, 'datenum');
                dataFileTb.camPaths{i} = cellfun(@(x,y) fullfile(x,y), fileInfo.folder, fileInfo.name, 'Uni', false);
            end
        end
    end
end

clear satNameParts animalId sessionDatetime subId queryStr isHit fileInfo i


% Select sessions for final output
dataFileTb.isSelected = false(height(dataFileTb), 1);

sessionFullName = cellfun(@(x,y,z) strtrim([x ' ' datestr(y, 'yyyy-mm-dd') ' ' z]), ...
    dataFileTb.animalId, ...
    num2cell(dataFileTb.sessionDatetime), ...
    dataFileTb.subId, ...
    'Uni', false);

selectedInd = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'SelectionMode', 'multi', ...
    'ListSize', [300 400], ...
    'ListString', sessionFullName);

dataFileTb.isSelected(selectedInd) = true;

clear sessionFullName selectedInd


%% Process data and add them to one master file

% Specify the preprocessing workspace
masterDir = MBrowse.Folder('D:\preprocessing', 'Select a preprocessing workspace');


% Load supporting data for tracking
roiTemplate = imread('roi_template.tif');

classNetName = 'finished_net_is_tongue_out_20180831-01.mat';
classNet = load(classNetName);

regNetName = 'finished_net_tongue_bottom_lm_20180901-01-stage4.mat';
regNet = load(regNetName);


% Loop through selected sessions
for i = find(dataFileTb.isSelected)'
    
    % Get a session identifier
    sessionId = [ ...
        dataFileTb.animalId{i} ' ' ...
        datestr(dataFileTb.sessionDatetime(i), 'yyyy-mm-dd') ' ' ...
        dataFileTb.subId{i} ...
        ];
    sessionId = strtrim(sessionId);
    disp(['Start processing data for ' sessionId]);
    
    % Derive file and folder paths
    masterPath = fullfile(masterDir, [sessionId ' master.mat']);
    ksDir = fullfile(masterDir, [sessionId ' kilosort']);
    datPath = fullfile(ksDir, 'amplifier.dat');
    npyPath = fullfile(ksDir, 'spike_times.npy');
    csvPath = fullfile(ksDir, 'cluster_groups.csv');
    tkDir = fullfile(masterDir, [sessionId ' tracking']);
    tkPath = fullfile(tkDir, 'tracking_data.mat');
    
    % Initialize master file
    masterObj = matfile(masterPath, 'Writable', true);
    
    % Add SatellitesViewer data
    if isempty(whos(masterObj, 'satellites_data'))
        satData = struct();
        satData.file_path = dataFileTb.satPath{i};
        satData.txt = Satellites.ReadTxt(dataFileTb.satPath{i});
        masterObj.satellites_data = satData;
    end
    
    % Add Intan data
    if isempty(whos(masterObj, 'intan_data')) && ~isempty(dataFileTb.intanPaths{i})
        intanOps = SL.Preprocess.GetIntanOptions(ksDir);
        intanData = MIntan.ReadRhdFiles(dataFileTb.intanPaths{i}, intanOps);
        
        intanData.adc_data = MMath.Decimate(intanData.adc_data, 30);
        intanData.adc_time = downsample(intanData.adc_time, 30);
        
        masterObj.intan_data = intanData;
    end
    
%     % Run Kilosort
%     if exist(datPath, 'file') && ~exist(npyPath, 'file')
%         MKilosort.Sort(datPath);
%     end
    
    % Add Kilosort and TemplateGUI outputs
    if isempty(whos(masterObj, 'spike_data')) && exist(csvPath, 'file')
        spikeData = MKilosort.ImportResults(ksDir);
        masterObj.spike_data = spikeData;
    end
    
    % Run tracking
    if ~exist(tkPath, 'file') && ~isempty(dataFileTb.hsvPaths{i})
        hsvData = SL.Preprocess.Tracking(dataFileTb.hsvPaths{i}, ...
            'OutputDir', tkDir, ...
            'RoiTemplate', roiTemplate, ...
            'ClassNet', classNet.net, ...
            'RegNet', regNet.net, ...
            'NumWorker', 2);
        
        hsvData.info.classNetName = classNetName;
        hsvData.info.regNetName = regNetName;
        
        save(tkPath, '-struct', 'hsvData');
        masterObj.hsv_data = hsvData;
    end
    
    % Add tracking outputs
    if isempty(whos(masterObj, 'hsv_data')) && exist(tkPath, 'file')
        masterObj.hsv_data = load(tkPath);
    end
    
end

clear i sessionId


return
%% Standalone Kilosort

MKilosort.Sort(); % spike sorting
spikeData = MKilosort.ImportResults(); % output sorting results
masterObj = matfile(MBrowse.File([], 'Select a master file', '*.mat'), 'Writable', true);
masterObj.spike_data = spikeData;


%% Standalone tracking

% Find video files
vidPaths = MBrowse.Files([], 'Select video file(s)', '*.avi');

% Load supporting data
roiTemplate = imread('roi_template.tif');

classNetName = 'finished_net_is_tongue_out_20180831-01.mat';
classNet = load(classNetName);

regNetName = 'finished_net_tongue_bottom_lm_20180901-01-stage4.mat';
regNet = load(regNetName);

% Specify output folder
outputDir = 'EF0146 2018-09-11 tracking';

% Run tracking
hsvData = SL.Preprocess.Tracking(vidPaths, ...
    'OutputDir', outputDir, ...
    'RoiTemplate', roiTemplate, ...
    'ClassNet', classNet.net, ...
    'RegNet', regNet.net, ...
    'NumWorker', 1);

hsvData.info.classNetName = classNetName;
hsvData.info.regNetName = regNetName;

save(fullfile(outputDir, 'tracking_data.mat'), '-struct', 'hsvData');

% Save to master file
masterObj = matfile(MBrowse.File([], 'Select a master file', '*.mat'), 'Writable', true);
masterObj.hsv_data = hsvData;


%% Remove Intan amplifier data from master file

masterObj = matfile(MBrowse.File([], 'Select a master file', '*.mat'), 'Writable', true);
intanData = masterObj.intan_data;
intanData.amplifier_data = [];
intanData.amplifier_time = [];
masterObj.intan_data = intanData;


%% Update old HSV data format

for i = find(dataFileTb.isSelected)'
    
    % Get a session identifier
    sessionId = [ ...
        dataFileTb.animalId{i} ' ' ...
        datestr(dataFileTb.sessionDatetime(i), 'yyyy-mm-dd') ' ' ...
        dataFileTb.subId{i} ...
        ];
    sessionId = strtrim(sessionId);
    disp(['Start processing data for ' sessionId]);
    
    % Derive file and folder paths
    masterPathOld = fullfile('E:\Tongue preprocessed', [sessionId ' master.mat']);
    tkDir = fullfile(masterDir, [sessionId ' tracking']);
    tkPath = fullfile(tkDir, 'tracking_data.mat');
    
    % Old master file
    masterObjOld = matfile(masterPathOld, 'Writable', true);
    
    % Import previously computed tracking results
    if isempty(dataFileTb.hsvPaths{i})
        error('no video file paths');
    end
    hsvDataOld = masterObjOld.hsv_data;
    
    % Make tracking folder
    if ~isempty(tkDir) && ~exist(tkDir, 'dir')
        mkdir(tkDir);
    end
    
    % Find ROI transformation
    vidPaths = dataFileTb.hsvPaths{i};
    vid = MNN.ReadVideo(vidPaths{1}, 'FrameFunc', @rgb2gray);
    [~, tform] = MNN.RoiTransform(vid(:,1:500,:), roiTemplate, 'X');
    cropSize = size(roiTemplate);
    
    % Save an example of cropped frame
    mugshot = imwarp(vid(:,:,1), tform, 'OutputView', imref2d(cropSize));
    imwrite(mugshot, fullfile(tkDir, 'mugshot.png'));
    
    % Output
    hsvDataNew.info.filePaths = vidPaths;
    hsvDataNew.info.roiTemplate = roiTemplate;
    hsvDataNew.info.tform = tform;
    hsvDataNew.info.cropSize = cropSize;
    hsvDataNew.info.mugshot = mugshot;
    
    hsvDataNew.info.classNetName = classNetName;
    hsvDataNew.info.regNetName = regNetName;
    
    hsvDataNew.frame_time = cellfun(@(x) (0:numel(x)-1)'./400, hsvDataOld.is_tongue_out, 'Uni', false);
    hsvDataNew.is_tongue_out = hsvDataOld.is_tongue_out;
    hsvDataNew.prob_tongue_out = hsvDataOld.prob_tongue_out;
    hsvDataNew.tongue_bottom_lm = hsvDataOld.tongue_bottom_lm;
    hsvDataNew.tongue_bottom_area = cell(numel(vidPaths), 1);
    
    save(tkPath, '-struct', 'hsvDataNew');
end

