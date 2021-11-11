%% Learning Curves of Backtracking Sequences

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig2');


%% Load and preprocess seArrays

seArraySearch = MBrowse.Dir2Table(fullfile(datDir, 'Data learning', '* seArray.mat'));
seArrayPaths = fullfile(seArraySearch.folder, seArraySearch.name);
seArrays = cell(size(seArrayPaths));

parfor i = 1 : height(seArraySearch)
    disp(i);
    s = load(seArrayPaths{i});
    seArray = s.seArray;
    
    isBk = false(size(seArray));
    for j = 1 : numel(seArray)
        % Check backtracking trials
        seqId = seArray(j).GetColumn('behavValue', 'seqId');
        isBk(j) = any(ismember({'1231456', '5435210'}, seqId));
        
        % Exclude the first and the last trial
        seArray(j).RemoveEpochs([1 seArray(j).numEpochs]);
    end
    
    % Keep the first few backtracking sessions
    seArray = seArray(find(isBk,10));
    
    seArrays{i} = seArray;
end

% Remove animals without backtracking sessions
noBk = cellfun(@numel, seArrays) == 0;
seArrays(noBk,:) = [];

% Make a summary table for inspection
tb = table();
tb.se = seArrays;
for i = 1 : height(tb)
    tb.animalId{i} = tb.se{i}(1).userData.sessionInfo.animalId;
    tb.sessionId{i} = arrayfun(@SL.SE.GetID, tb.se{i}, 'Uni', false);
end


%% Compute learning curves

lcOps.maxTrials = 800;
lcOps.binSize = 100;
lcOps.transRange = 4:5;
lcOps.analysisNames = {'numTrials', 'seqDur_S', 'seqDur_B', 'transDur_S', 'transDur_B'};

statCell = cell(size(seArrays));
parfor i = 1 : numel(statCell)
    disp(i);
    statCell{i} = SL.Learn.ComputeLearningCurves(seArrays{i}, lcOps);
end


% %% Derive quantifications
% 
% for i = 1 : numel(statCell)
%     s = statCell{i};
%     
%     % Compute sequence duration ratio of backtracking over normal seq
%     s.seqDurRatio.x = s.seqDurN.x;
%     s.seqDurRatio.mean = s.seqDurB.mean ./ s.seqDurN.mean;
%     s.seqDurRatio.median = s.seqDurB.median ./ s.seqDurN.median;
%     
%     % Compute sequence duration ratio of backtracking over normal seq
%     s.transDurRatio.x = s.transDurN.x;
%     s.transDurRatio.mean = s.transDurB.mean ./ s.transDurN.mean;
%     s.transDurRatio.median = s.transDurB.median ./ s.transDurN.median;
%     
%     statCell{i} = s;
% end


%% Plotting

ss = cat(1, statCell{:});

x = ss(1).binCenters;
% cEach = repmat([0 0 0 .2], [numel(ss) 1]);
% cEach = MPlot.Rainbow(numel(ss));
% cEach(5,:) = [1 0 0 1];

name2plot = {'seqDur_S', 'seqDur_B', 'transDur_S', 'transDur_B'};
titles = {'Standard seq. duration', 'Backtracking seq. duration', ...
    'Standard 4th interval', 'Backtracking 4th interval'};


f = MPlot.Figure(456); clf

for k = 1 : numel(name2plot)
    np = name2plot{k};
    
    ax = subplot(2,2,k);
    
    switch np
        case {'seqDur_S', 'seqDur_B', 'transDur_S', 'transDur_B'}
%             for i = 1 : length(ss)
%                 y = ss(i).(np).median * 1e3;
%                 plot(x, y, '-', 'Color', cEach(i,:)); hold on
%                 % text(x(end), y(end), num2str(i));
%             end
            yy = arrayfun(@(x) x.(np).median * 1e3, ss, 'Uni', false);
            
        case {'seqDurRatio', 'transDurRatio'}
%             for i = 1 : length(ss)
%                 y = ss(i).(np).median;
%                 plot(x, y, '-', 'Color', cEach(i,:)); hold on
%                 % text(x(end), y(end), num2str(i));
%             end
            yy = arrayfun(@(x) x.(np).median, ss, 'Uni', false);
            ax.YScale = 'log';
    end
    yy = cell2mat(yy');
    plot(x', yy, '-', 'Color', [0 0 0 .2]); hold on
    plot(x', nanmean(yy,2), '-', 'Color', 'k'); hold on
    ax.YScale = 'log';
    
    switch np
        case {'seqDur_S', 'seqDur_B'}
            ax.YLim = [.7e3 3e4];
            ax.YTick = [1e3 1e4];
            ax.YTickLabel = ax.YTick ./ 1e3;
            ylabel('second');
            
        case {'transDur_S', 'transDur_B'}
            ax.YLim = [100 2e4];
            ax.YTick = [1e2 1e3 1e4];
            ax.YTickLabel = ax.YTick ./ 1e3;
            ylabel('second');
            
        case {'seqDurRatio', 'transDurRatio'}
            ax.YLim = [1 1e2];
            ax.YTick = [1 10 100];
            ax.YTickLabel = ax.YTick;
    end
    SL.Learn.FormatLearningCurveAxes(ax, x);
    ax.XTick = 100:200:700;
    ax.XTickLabel = ax.XTick;
    title(titles{k});
end

MPlot.Paperize(f, 'ColumnsWide', .75, 'AspectRatio', .75);
saveFigurePDF(f, fullfile(figDir, 'learning curves'));


% Report stats
fileID = fopen(fullfile(figDir, 'learning curves.txt'), 'w');
fprintf(fileID, 'Include %d mice\n', numel(ss));
for i = 1 : numel(ss)
    fprintf(fileID, '%s\n', ss(i).sessionInfo.animalId);
end
fclose(fileID);

