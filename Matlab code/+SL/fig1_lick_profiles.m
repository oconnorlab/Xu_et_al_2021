%% Characterize licks at each position

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig1');


%% Compute lick profiles from previosuly extracted lick data

cachePath = fullfile(figDir, 'computed lick profiles.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Load cached data from fig1_seq_stats.m
    load(fullfile(figDir, 'extracted lick data.mat'));
    
    isExclude = ismember(seTbCat.sessionId, SL.Data.excludeFromTouch);
    isInclude = ismember(seTbCat.seqId, {'123456', '543210'});
    seTbCat = seTbCat(isInclude & ~isExclude, :);
    
    % Extract and preprocess lickObj
    lickObj = cellfun(@(x) cat(1,x{:}), seTbCat.lickObj, 'Uni', false);
    for i = 1 : numel(lickObj)
        % Select licks
        licks = lickObj{i};
        lickMask = licks.IsTracked & ([licks.isDrive]' | [licks.isReward]');
        licks = licks(lickMask);
        
        if ~isempty(licks)
            % Add tags to lickObj
            licks = licks.SetVfield('seqId', repmat(seTbCat.seqId(i), size(licks)));
            licks = licks.SetVfield('lickId', [licks.portPos]');
        end
        
        lickObj{i} = licks;
    end
    lickObj = cat(1, lickObj{:});
    
    % Resample lick data
    lickIds = 0 : 6;
    quantNames = {'length', 'velocity', 'angle', 'forceV', 'forceH'};
    pCI = 0.05;
    s = SL.Behav.ComputeLickProfile(lickObj, lickIds, quantNames, pCI);
    
    % Cache results
    save(cachePath, 'lickIds', 'quantNames', 'pCI', 's');
end


%% Plot lick profiles

f = MPlot.Figure(13201); clf
for i = 1 : numel(quantNames)
    ax = subplot(numel(quantNames), 1, i);
    SL.BehavFig.LickProfile(s, quantNames{i}, 'ErrorType', 'CI', 'Color', [0 0 0]);
    ax.XTickLabel = ["R"+(3:-1:1), "Mid", "L"+(1:3)];
    switch quantNames{i}
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
            ax.YLabel.String = '\theta (deg)';
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

MPlot.Paperize(f, 'ColumnsWide', .5, 'AspectRatio', 1.75);
saveFigurePDF(f, fullfile(figDir, 'lick profiles'));


