%% Compute average stimulus traces

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, figName);
cachePath = fullfile(figDir, 'stim seq-seq.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Load data
    if strcmp(figName, 'Fig5')
        dataSource = MBrowse.Dir2Table(fullfile(figDir, 'dec seq-seq-seq *.mat'));
    elseif strcmp(figName, 'FigZ')
        dataSource = MBrowse.Dir2Table(fullfile(figDir, 'dec seq_zz-seq_zz-seq_zz *.mat'));
    end
    
    decTb = cell(height(dataSource), 1);
    for i = 1 : numel(decTb)
        decTb{i} = load(fullfile(dataSource.folder{i}, dataSource.name{i}));
    end
    decTb = cat(1, decTb{:});
    decTb = struct2table(decTb, 'AsArray', true);
    
    % Combine data across areas
    ops = SL.Param.Transform;
    comTb = cat(1, decTb.comTb{:});
    conds = cell2table({ ...
        '123456', -1; ...
        '543210', -1; ...
        '1231456', -1; ...
        '5435210', -1; ...
        '123432101234', -1; ...
        '321012343210', -1; ...
        }, ...
        'VariableNames', ops.conditionVars);
    conds.seqId = SL.Param.CategorizeSeqId(conds.seqId);
    comTb = SL.SE.CombineConditions(conds, comTb);
    comTb.reg = [];
    comTb.pca = [];
    
    % Compute mean stats
    mcomTb = SL.SE.SetMeanArrays(comTb);
    mcomTb = SL.PopFig.SetPlotParams(mcomTb);
    
    sReg = decTb.sReg{1}(1);
    
    save(cachePath, 'mcomTb', 'sReg');
end


%% Plot mean stimuli

fprintf('Include %i trials in total\n', sum(cell2mat(mcomTb.numMatched)));

ops = SL.Param.Transform;
ops = SL.Param.Resample(ops);
sInd = sReg.sInd;

f = MPlot.Figure(7410); clf

if strcmp(figName, 'FigZ')
    SL.PopFig.PlotMeanStim(mcomTb, ops, sInd, @SL.PopFig.FormatStimAxesZZ);
else
    SL.PopFig.PlotMeanStim(mcomTb, ops, sInd, @SL.PopFig.FormatStimAxes);
end

MPlot.Paperize(f, 'ColumnsWide', .35, 'AspectRatio', 3.3);
saveFigurePDF(f, fullfile(figDir, "average stimuli in seq"));




