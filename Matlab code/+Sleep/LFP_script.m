%% Prepare data

% Extract data
lfpTb = se.GetTable('LFP');
t = lfpTb.time{end};
lfp = lfpTb.series1{end};

% Filter signals
fs = se.userData.intanInfo.lfp.samplingRate;
lfp = bandpass(lfp, [1 50], fs); % e.g. between 1 to 50 Hz

% Normalize signals
lfpZs = zscore(lfp);

% Average signals across channels
lfpZsMed = median(lfpZs, 2);

% Select a time window of interest
tWin = [0 max(t)]; %[0 30] * 60; % e.g. from 10 to 30 minutes
tShort = t(t > tWin(1) & t < tWin(2));
lfpShort = lfpZsMed(t > tWin(1) & t < tWin(2));

% Cut off big artifacts
lfpLim = std(lfpZsMed) * 3;
lfpPlot = MMath.Bound(lfpShort, [-lfpLim lfpLim]);


%% Compute spectral estimate

fLims = [0 30];

[P,F,T] = pspectrum(lfpShort, tShort, ...
    'spectrogram', ...
    'FrequencyLimits', fLims, ...
    'TimeResolution', 1, ...
    'OverlapPercent', 50);


%% Compute spectral estimate

fLims = [0 30];

[P,F,T] = pspectrum(lfpShort, tShort, ...
    'spectrogram', ...
    'FrequencyLimits', fLims, ...
    'FrequencyResolution', 1, ...
    'OverlapPercent', 50);


%% Plot trace and power spectrum

f = figure(532); clf
f.Color = 'w';

plot(tShort, lfpPlot*2 + fLims(2) + 5, 'k'); hold on
imagesc(T, F, P); hold on

colormap parula
colorbar
caxis([0 0.2]);
xlim(tWin);
ylim([0, fLims(2)+10]);
xlabel('time (s)');
title('Top: normalized mean LFP signal (AU); Bottom: spectrogram frequency (Hz)');

ax = gca;
ax.TickLength(1) = 0;
ax.YDir = 'normal';
ax.Box = 'off';


