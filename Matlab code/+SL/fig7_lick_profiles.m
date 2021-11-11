%% Characterize licks in response to backtracking

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig7');


%% Load lickObjs

% Load cached data from fig1_perf_stats.m
fig1Dir = fullfile(datDir, SL.Data.figDirName, 'Fig1');
load(fullfile(fig1Dir, 'extracted lick data.mat'));


%% Process lickObjs

lickObj = seTbCat.lickObj;
numTrials = 0;

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
            
            % Label licks wrt first water touch
            tWater = seTbCat.tWater{r}(k);
            tTouch = licks.GetTfield('tTouchOn');
            idx = find(tTouch - tWater >= 0, 1);
            if isempty(idx)
                idx = numel(licks)+1;
            end
            ids = (1 : numel(licks))';
            ids = ids - idx;
            ids(isnan(tTouch)) = NaN;
            licks = licks.SetVfield('lickId', ids);
            
            numTrials = numTrials + 1;
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
    lickIds = -2 : 4;
    quantNames = {'length', 'velocity', 'angle', 'force'};
    pCI = 0.05;
    
    licks = cat(1, lickObj{:});
    sProf = SL.Behav.ComputeLickProfile(licks, lickIds, quantNames, pCI);
    
    save(cachePath, 'lickIds', 'quantNames', 'pCI', 'sProf', 'numTrials');
end


%% Plot lick profiles

fprintf('Included %d trials in total\n', numTrials);

quant2plot = quantNames;
quant2plot = {'length', 'velocity', 'angle', 'force'};

f = MPlot.Figure(8903); clf
for i = 1 : numel(quant2plot)
    ax = subplot(numel(quant2plot), 1, i);
    SL.BehavFig.LickProfile(sProf, quant2plot{i}, 'ErrorType', 'CI', 'Color', [0 0 0]);
    ax.XTickLabel = lickIds;
    switch quant2plot{i}
        case 'length'
            ax.YLim = [0 3];
            ax.YTick = 0:3;
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = 'L (mm)';
        case 'angle'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
            ax.YLim = [0 40];
            ax.YTick = [0 20 40];
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = '\Theta (deg)';
        case 'velocity'
            ax.YLim = [-300 200];
            ax.YTick = -200:200:200;
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = 'L'' (mm/s)';
        case 'force'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
            ax.YLim = [0 5];
            ax.YLabel.String = 'F_{total} (mN)';
    end
end
MPlot.Paperize(f, 'ColumnsWide', .33, 'ColumnsHigh', .6);
saveFigurePDF(f, fullfile(figDir, 'lick profiles'));

