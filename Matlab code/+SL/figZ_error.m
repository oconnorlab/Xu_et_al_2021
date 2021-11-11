%% Neural trajectory in successful vs error sequences

datDir = SL.Param.GetAnalysisRoot;
figDir = fullfile(datDir, SL.Param.figDirName, 'FigZ');

% Load example session
sessionId = 'MX200101 2020-11-26';
seSearch = MBrowse.Dir2Table(fullfile(datDir, '**', [sessionId ' se enriched.mat']));
lmSearch = MBrowse.Dir2Table(fullfile(datDir, '**', ['lm ' sessionId '.mat']));
load(fullfile(seSearch.folder{1}, seSearch.name{1}));
load(fullfile(lmSearch.folder{1}, lmSearch.name{1}));

% Add information of sequence breaks
bv = SL.Behav.AddBreakInfo(se);

% Preprocessing: align to first drive, split by seq type and first break
ops = SL.Param.Transform;
ops.maxEndTime = 12;
ops.isMorph = true;
ops.alignType = 'first_drive';
ops.conditionVars = {'seqId', 'firstBreakStep'};
seTb = SL.SE.Transform(se, ops);

% Compute state trajectory
ops = SL.Param.Resample(ops);
ops.hsvVars = {'tongue_bottom_length'};
ops.adcVars = {};
ops.valVars = {};
ops.rsWin = [-0.1 2];
ops.rsBinSize = 0.01;
seTb = SL.SE.SetStimRespArrays(seTb, ops);
seTb = SL.Pop.SetProjArrays(seTb, mdls, 6);


%% 

for i = 1 : height(seTb)
    if seTb.numTrial(i) < 8
        continue
    end
    
    [m, sd, ~, ci] = MMath.MeanStats(seTb.stim{i}, 3);
    seTb.avgStim{i} = cat(3, m, sd, ci);
    
    [m, sd, ~, ci] = MMath.MeanStats(seTb.reg{i}, 3);
    seTb.avgReg{i} = cat(3, m, sd, ci);
    
    [m, sd, ~, ci] = MMath.MeanStats(seTb.pca{i}, 3);
    seTb.avgPCA{i} = cat(3, m, sd, ci);
end

seTb = SL.Pop.SetMeanDeviationArrays(seTb);


%% 

isSelect = seTb.seqId == SL.Param.zzSeqs{1} & seTb.numTrial >= 8;

f = MPlot.Figure(65432); clf
SL.PopFig.PlotBreakReg(seTb(isSelect,:), mdls.reg, 3:5);
MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', 1.2);

f = MPlot.Figure(65442); clf
SL.PopFig.PlotBreakPCA(seTb(isSelect,:), 1:3);
MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', 1.2);

f = MPlot.Figure(65452); clf
SL.PopFig.PlotBreakDeviation(seTb(isSelect,:));
MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', 1.1);


%% 

for i = 1 : height(seTb)
    if seTb.numTrial(i) < 8
        continue
    end
    
    M = permute(seTb.pca{i}, [3 2 1]); % convert to trial-by-pc-by-time
    clear D
    for t = size(M,3) : -1 : 1
        D(t,:) = pdist(M(:,:,t));
    end
    [m, sd, ~, ci] = MMath.MeanStats(D, 2);
    seTb.avgDist{i} = cat(2, m, sd, ci);
end


%% 

ind = bv.firstBreakLen >= 2;
s = bv.firstBreakStep(ind);
s = accumarray(s, 1);


f = MPlot.Figure(1); clf
bar((1:numel(s))', s);
% f.Children.XTickLabel = [4; bv.posIndex{1}];




