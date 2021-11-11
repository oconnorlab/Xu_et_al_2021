%% Characterize licks in response to backtracking

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig2');


%% Load lickObjs

% Load data cached from fig1_perf_stats.m
load(fullfile(datDir, SL.Data.figDirName, 'Fig1', 'extracted lick data.mat'));

% Exclude flawed sessions
isBadTouch = ismember(seTbCat.sessionId, SL.Data.excludeFromTouch);

% Exclude sessions without backtracking
[G, sessionId] = findgroups(seTbCat.sessionId);
isBackG = splitapply(@(x) any(ismember(x, {'1231456', '5435210'})), seTbCat.seqId, G);
isBack = ismember(seTbCat.sessionId, sessionId(isBackG));

seTbCat(isBadTouch | ~isBack,:) = [];


%% Process lickObjs

lickObj = seTbCat.lickObj;

for r = 1 : numel(lickObj) % through session conditions
    for k = 1 : numel(lickObj{r}) % through trials
        % Select licks
        licks = lickObj{r}{k};
        licks = licks(licks.IsTracked);
        
        if ~isempty(licks)
            % Invert direction
            if licks(1).portPos == 0
                licks = licks.InvertDirection;
            end
            
            % Label licks wrt Mid
            tMid = seTbCat.tMid{r}(k);
            tLicks = double(licks);
            [~, iTrig] = min(abs(tLicks - tMid));
            ids = (1 : numel(licks))';
            ids = ids - iTrig;
            ids(tLicks - tMid > 2) = NaN;
            licks = licks.SetVfield('lickId', ids);
        end
        
        lickObj{r}{k} = licks;
    end
end

lickObj = cellfun(@(x) cat(1,x{:}), lickObj, 'Uni', false);


%% Compute lick profiles

cachePath = fullfile(figDir, 'computed lick profiles.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Compute new
    lickIds = -1 : 5;
    quantNames = {'length', 'velocity', 'angle', 'forceV', 'forceH'};
    pCI = 0.05;
    
    % Compute lick profiles for NN
    isInclude = ismember(seTbCat.seqId, {'123456', '543210'});
    licks = cat(1, lickObj{isInclude});
    sNN = SL.Behav.ComputeLickProfile(licks, lickIds, quantNames, pCI);
    
    % Compute lick profiles for BB
    isInclude = ismember(seTbCat.seqId, {'1231456', '5435210'});
    licks = cat(1, lickObj{isInclude});
    sBB = SL.Behav.ComputeLickProfile(licks, lickIds, quantNames, pCI);
    
    save(cachePath, 'lickIds', 'quantNames', 'pCI', 'sNN', 'sBB');
end


%% Plot lick profiles

quant2plot = quantNames;
quant2plot = {'length', 'velocity', 'angle'};

f = MPlot.Figure(28903); clf
for i = 1 : numel(quant2plot)
    ax = subplot(numel(quant2plot), 1, i);
    SL.BehavFig.LickProfile(sNN, quant2plot{i}, 'ErrorType', 'SD', 'Color', [0 0 0]);
    SL.BehavFig.LickProfile(sBB, quant2plot{i}, 'ErrorType', 'SD', 'Color', [0 .7 0]);
    ax.XTickLabel = lickIds;
    switch quant2plot{i}
        case 'length'
            ax.YLim = [0 3];
            ax.YTick = 0:3;
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = 'L (mm)';
        case 'angle'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
            ax.YLim = [-40 40];
            ax.YTick = -30:30:30;
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = '\Theta (deg)';
        case 'velocity'
            ax.YLim = [-300 200];
            ax.YTick = -200:200:200;
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = 'L'' (mm/s)';
        case 'forceV'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
            ax.YLim = [-2 5];
            ax.YLabel.String = 'F_{vert} (mN)';
        case 'forceH'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
            ax.YLim = [-1.5 1.5];
            ax.YLabel.String = 'F_{hori} (mN)';
    end
end
MPlot.Paperize(f, 'ColumnsWide', .5, 'AspectRatio', 1);
saveFigurePDF(f, fullfile(figDir, 'lick profiles'));

