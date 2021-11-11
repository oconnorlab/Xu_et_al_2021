%% 

datDir = SL.Data.analysisRoot;
movDir = fullfile(datDir, SL.Data.figDirName, 'Movies');

if ~exist('mp', 'var')
    load('sl mp vid.mat');
end


%% Movie 1: standard sequence

% MX180202 20180504 Num69
dataSource = SL.Data.Dir2Table(fullfile(datDir, '**\MX180202 2018-05-04 se enriched.mat'));
se = SL.SE.LoadSession(dataSource.path{1});

mp.GUI; % manually navigate to trial Num69, set time range to 0-2.5 s
mp.plotTable.axesObj{1}.Title.String = 'Standard sequence';

% Generate movie
movPath = fullfile(movDir, 'Movie 1 standard sequence');
xSlow = 5;
SL.BehavFig.SaveExampleMovie(movPath, mp, xSlow);


%% Movie 2: backtracking sequence

% MX180601 20180727 Num40
dataSource = SL.Data.Dir2Table(fullfile(datDir, '**\MX180601 2018-07-27 se enriched.mat'));
se = SL.SE.LoadSession(dataSource.path{1});

mp.GUI; % manually navigate to trial Num40, set time range to 0-2.5 s
mp.plotTable.axesObj{1}.Title.String = 'Backtracking sequence';

% Generate movie
movPath = fullfile(movDir, 'Movie 2 backtracking sequence');
xSlow = 5;
SL.BehavFig.SaveExampleMovie(movPath, mp, xSlow);


%% Movie 3: inhibition in S1TJ at initiation

% MX180803 20180821 Num125
dataSource = SL.Data.Dir2Table(fullfile(datDir, '**\MX180803 2018-08-21 se enriched.mat'));
se = SL.SE.LoadSession(dataSource.path{1});

mp.GUI; % manually navigate to trial Num125, set time range to 0-3.5 s
mp.plotTable.axesObj{1}.Title.String = 'Inhibiting S1TJ at sequence initiation';

% Generate movie
movPath = fullfile(movDir, 'Movie 3 inhibiting S1TJ at init');
xSlow = 5;
SL.BehavFig.SaveExampleMovie(movPath, mp, xSlow);


%% Movie 4: inhibition in ALM/M1TJ at initiation

% MX181002 20181010 Num19
dataSource = SL.Data.Dir2Table(fullfile(datDir, '**\MX181002 2018-10-10 se enriched.mat'));
se = SL.SE.LoadSession(dataSource.path{1});

mp.GUI; % manually navigate to trial Num19, set time range to 0-3.5 s
mp.plotTable.axesObj{1}.Title.String = 'Inhibiting ALM/M1TJ at sequence initiation';

% Generate movie
movPath = fullfile(movDir, 'Movie 4 inhibiting ALM-M1TJ at init');
xSlow = 5;
SL.BehavFig.SaveExampleMovie(movPath, mp, xSlow);


%% Movie 5: inhibition in M1B at consumption w low power

% MX180803 20180819 Num139
dataSource = SL.Data.Dir2Table(fullfile(datDir, '**\MX180803 2018-08-19 se enriched.mat'));
se = SL.SE.LoadSession(dataSource.path{1});

mp.GUI; % manually navigate to trial Num139, set time range to 0-3.5 s
mp.plotTable.axesObj{1}.Title.String = 'Inhibiting M1B during water consumption';

% Generate movie
movPath = fullfile(movDir, 'Movie 5 Inhibiting M1B at cons w half power');
xSlow = 5;
SL.BehavFig.SaveExampleMovie(movPath, mp, xSlow);


%% Movie 6: zigzag sequence

% MX180202 20180504 Num69
dataSource = SL.Data.Dir2Table(fullfile(datDir, '**\MX200101 2020-11-26 se enriched.mat'));
se = SL.SE.LoadSession(dataSource.path{1});

mp.GUI; % manually navigate to trial Num49, set time range to 0-2.5 s
mp.plotTable.axesObj{1}.Title.String = 'Zigzag sequence';

% Generate movie
movPath = fullfile(movDir, 'Movie 6 zigzag sequence');
xSlow = 5;
SL.BehavFig.SaveExampleMovie(movPath, mp, xSlow);

