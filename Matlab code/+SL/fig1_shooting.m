%% Characterize licks at each position

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig1');


%% Compute lick profiles

cachePath = fullfile(figDir, 'computed shooting profile.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Load cached data
    load(fullfile(figDir, 'extracted lick data.mat'));
    
    isExclude = ismember(seTbCat.sessionId, SL.Data.excludeFromTouch);
    isInclude = ismember(seTbCat.seqId, {'123456', '543210'});
    seTbCat = seTbCat(isInclude & ~isExclude, :);
    
    % Extract and preprocess lickObj
    lickObj = cellfun(@(x) cat(1,x{:}), seTbCat.lickObj, 'Uni', false);
    for i = 1 : numel(lickObj)
        % Select licks
        licks = lickObj{i};
        lickMask = licks.IsTracked & ([licks.isDrive]' | [licks.isReward]') & ismember([licks.portPos]', [0 6]);
        licks = licks(lickMask);
        
        if ~isempty(licks)
            % Invert direction
            isInvert = [licks.portPos]' == 6;
            licks(isInvert) = licks(isInvert).InvertDirection;
            
            % Tag licks
            licks = licks.SetVfield('lickId', zeros(size(licks)));
        end
        
        lickObj{i} = licks;
    end
    lickObj = cat(1, lickObj{:});
    
    % Resample lick data
    lickIds = 0;
    quantNames = {'length', 'velocity', 'angle'};
    pCI = 0;
    s = SL.Behav.ComputeLickProfile(lickObj, lickIds, quantNames, pCI);
    
    % Cache results
    save(cachePath, 'quantNames', 'pCI', 's');
end


%%

% Convert length to fraction length
L = s.length.samples{1};
L = L ./ nanmax(L);
[s.length.mean{1}, s.length.sd{1}, s.length.se{1}] = MMath.MeanStats(L, 2);

% Compute histograms
t = s.length.t{1};
dt = t(2) - t(1);
tEdges = [t-dt/2; t(end)+dt/2];

tTO = s.tTouch.samples{1}(:,1);
nTO = histcounts(tTO, tEdges, 'Normalization', 'probability');

[~, indMaxL] = nanmax(s.length.samples{1});
tMaxL = t(indMaxL);
nMaxL = histcounts(tMaxL, tEdges, 'Normalization', 'probability');

[~, indMaxA] = nanmax(s.angle.samples{1});
tMaxA = t(indMaxA);
nMaxA = histcounts(tMaxA, tEdges, 'Normalization', 'probability');
tPrctA = prctile(tMaxA, 50);

Lshoot = interp1(t, s.length.mean{1}, tPrctA);
indShoot = zeros(1, size(L,2));
for i = 1 : size(L,2)
    indShoot(i) = find(L(:,i) > Lshoot, 1);
end
tShoot = t(indShoot);
nShoot = histcounts(tShoot, tEdges, 'Normalization', 'probability');


%% Plot lick profiles

quant2plot = {'angle', 'length'};
nRows = numel(quant2plot) + 1;

f = MPlot.Figure(78465); clf

for i = 1 : numel(quant2plot)
    ax = subplot(nRows, 1, i);
    SL.BehavFig.LickProfile(s, quant2plot{i}, 'ErrorType', 'SE', 'Color', [0 0 0]);
    ax.XLim = 1+[-.5 .5];
    ax.XAxis.Visible = 'off';
    switch quant2plot{i}
        case 'length'
            plot(ax.XLim, [Lshoot Lshoot], 'r:');
            ax.YLim = [0 1];
            ax.YTick = [0 round(Lshoot,2) 1];
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = 'L / L_{max}';
        case 'angle'
            ax.YLim = [10 30];
            ax.YTick = ax.YLim;
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = '|\theta| (°)';
        case 'velocity'
            ax.YLim = [-300 200];
            ax.YTick = -200:200:200;
            ax.YTickLabel = ax.YTick;
            ax.YLabel.String = 'L'' (mm/s)';
    end
    plot([tPrctA; tPrctA]*0.4+1, ax.YLim', 'r:');
end

ax = subplot(nRows, 1, 3); cla
vPos = 0:.25:.75;
MPlot.Violin(vPos, [t t t t]*0.4+1, [nShoot' nMaxL' nMaxA' nTO'], ...
    'Percentiles', [25 50 75], ...
    'Color', [0 0 0]+.3, ...
    'Orientation', 'horizontal', ...
    'Alignment', 'low');
ax.XLim = 1+[-.5 .5];
ax.YLim = [0 1];
ax.XAxis.Visible = 'off';
ax.YTick = vPos;
ax.YTickLabel = {'P(\theta_{shoot})', 'P(L_{max})', 'P(|\theta|_{max})', 'P_{touch onset}'};

MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', .75);
saveFigurePDF(f, fullfile(figDir, 'shooting profile'));


