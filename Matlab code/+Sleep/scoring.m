%% Load SE and specify video paths

mainDir = '';

% sePath = MBrowse.File('', 'Select a SE file');
sePath = fullfile(mainDir, 'NH190201 2019-07-25 s2 se enriched.mat');
seRaw = SL.SE.LoadSession(sePath);


%% Add pre-task data as the first epoch

% Duplicate SE and keep the first trial as a placeholder
sePre = seRaw.Duplicate();
sePre.RemoveEpochs(2:seRaw.numEpochs);

% Replace with pre-task data
sePre.SetReferenceTime(0);
sePre.SetColumn('behavValue', 'trialNum', 0);
sePre.SetTable('LFP', seRaw.userData.preTaskData.LFP);
sePre.SetTable('adc', seRaw.userData.preTaskData.adc);
sePre.SetTable('spikeTime', seRaw.userData.preTaskData.spikeTime);
SL.SE.EnrichAll(sePre);

% Merge pre-task SE with task SE
sePre.userData = [];
se = Merge(sePre, seRaw);
se.userData = rmfield(se.userData, 'preTaskData');

se.Preview();


%% Add new data

Sleep.SE.EnrichLPF(se);

Sleep.SE.AddStateTable(se);

se.Preview();


%% Save SE

save(uiputfile('*.mat'), 'se');





