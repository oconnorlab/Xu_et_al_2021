% Plot example units

datDir = SL.Data.analysisRoot;

if ~exist('powerName', 'var')
    powerName = "5V";
end

figDir = fullfile(datDir, SL.Data.figDirName, 'Fig3', powerName);

if ~exist(figDir, 'dir')
    mkdir(figDir);
end


%% Load SEs

%{
Inhibition in S1TJ
MX180803 2018-08-21 Num125 (Init; used for movie) Num64/200/129 (Mid)

Inhibition in ALM
MX181002 2018-10-10 Num19 (Init; used for movie)
MX180803 2018-08-06 Num219/215 (Mid)
MX180804 2018-08-06 Num71/115/57/145 (Mid)

Inhibition in S1BF
MX180803 2018-08-20 Num363 (Mid)

Inhibition in M1B
MX180803 20180819 Num139 (Cons)
%}

% SE
seSearch = [ ...
    MBrowse.Dir2Table(fullfile(datDir, '**/MX180803 2018-08-21 se enriched.mat')); ... % S1TJ
    MBrowse.Dir2Table(fullfile(datDir, '**/MX180804 2018-08-06 se enriched.mat')); ... % ALM+M1TJ
    MBrowse.Dir2Table(fullfile(datDir, '**/MX180803 2018-08-20 se enriched.mat')); ... % S1BF
    ];
sePaths = cellfun(@fullfile, seSearch.folder, seSearch.name, 'Uni', false);
seArray = SL.SE.LoadSession(sePaths);

% Metadata
xlsAll = MBrowse.ReadXls(SL.Data.metadataSheet, 'Opto');
xlsSub = SL.SE.AddXlsInfo2SE(seArray, xlsAll);


%% Example trials

trialNums = [64 57 363];

for k = 1 : numel(seArray)
    
    % Get data
    seK = seArray(k);
    trialIdx = find(seK.epochInd == trialNums(k), 1);
    [bt, bv, hsv, adc] = seK.GetTable('behavTime', 'behavValue', 'hsv', 'adc');
    
    % Ploting
    f = MPlot.Figure(12120+k); clf
    nRows = 3;
    tWin = [0 2.2];
    i = 0;
    
    i = i + 1;
    ax = subplot(nRows,1,i); cla
    SL.OptoFig.TrialOptoStim(trialIdx, adc);
    ax.XLim = tWin;
    
    i = i + 1;
    ax = subplot(nRows,1,i); cla
    SL.OptoFig.TrialAngle(trialIdx, bt, hsv);
    SL.OptoFig.TrialTouch(trialIdx, bt);
    ax.XLim = tWin;
    
    i = i + 1;
    ax = subplot(nRows,1,i); cla
    SL.OptoFig.TrialLength(trialIdx, bt, hsv);
    SL.OptoFig.TrialTouch(trialIdx, bt);
    ax.XLim = tWin;
    
    MPlot.Paperize(f, 'ColumnsWide', .66, 'ColumnsHigh', .4);
    saveFigurePDF(f, fullfile(figDir, ['example trial for ' seK.userData.xlsInfo.area]));
    
end

