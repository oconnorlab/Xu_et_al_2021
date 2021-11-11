%% 

if ~exist('predType', 'var')
    predType = 'pca';
end

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'FigZ');

zzDirName = 'Data ephys ZZ';
seTbSearch = MBrowse.Dir2Table(fullfile(datDir, zzDirName, 'seq_zz dt_0', 'seTb *.mat'));
mdlsSearch = MBrowse.Dir2Table(fullfile(datDir, zzDirName, 'seq_zz dt_0', 'lm *.mat'));


%% Sequence type classification in each session

isOverwrite = false;

for i = 1 : height(seTbSearch)
    % Make cache path
    seTbNameParts = strsplit(seTbSearch.name{i}, {' ', '.'});
    sessionId = SL.SE.GetID(seTbNameParts{2:3});
    cachePath = fullfile(seTbSearch.folder{i}, ['cla_' predType ' ' sessionId '.mat']);
    
    if exist(cachePath, 'file') && ~isOverwrite
        warning('%s already exists and will not be overwritten', ['cla_' predType ' ' sessionId '.mat']);
        continue
    end
%     load(cachePath);
%     claTbCached = claTb;
    
    % Load seTb and mdls
    load(fullfile(seTbSearch.folder{i}, seTbSearch.name{i}));
    load(fullfile(mdlsSearch.folder{i}, mdlsSearch.name{i}));
    
    % Make seTbs with shifted time
    seTbSft = SL.ZZ.ShiftSeTb(seTb);
    
    % Set parameters
    ops = mdls.ops;
    ops.rsWin = SL.ZZ.claWin;
    ops.rsBinSize = SL.ZZ.claBinSize;
    ops.hsvVars = {'theta_shoot', 'tongue_bottom_angle', 'tongue_bottom_length'};
    ops.adcVars = {};
    ops.valVars = {};
    ops.derivedVars = {};
    ops.dimCombine = [];
    ops.claVars = {'theta_shoot'};
    ops.alpha = 0.05;
    
    % Go through each shift
    claTb = cell(size(seTbSft));
    for j = 1 : numel(seTbSft)
        % Get arrays of stim, resp and projection
        seTb = seTbSft{j};
        seTb = SL.SE.SetStimRespArrays(seTb, ops);
        seTb = SL.Pop.SetProjArrays(seTb, mdls, 12); % taking 12 dimensions
        
        % Classify sequence type on original and shifted data
        claTb{j} = SL.ZZ.ClassifyShiftMatched(seTb, predType, ops);
%         claTb{j} = claTbCached(j,:);
        
        % Save addtional variables for reviewing
        claTb{j}.stim1{1} = permute(seTb.stim{1}, [3 2 1]);
        claTb{j}.stim2{1} = permute(seTb.stim{2}, [3 2 1]);
    end
    claTb = cat(1, claTb{:});
    
    % Save result
    disp('Save classification results');
    save(cachePath, 'claTb', 'ops');
end

% Load session classification data
claSearch = MBrowse.Dir2Table(fullfile(datDir, zzDirName, 'seq_zz dt_0', ['cla_' predType ' *.mat']));
claTbArray = cell(size(seTbSearch.name));
for i = 1 : height(claSearch)
    load(fullfile(claSearch.folder{i}, claSearch.name{i}));
    claTbArray{i} = claTb;
end


%% Plot classification accuracy for single sessions

for i = 1 : numel(claTbArray)
    f = MPlot.Figure(40); clf
    claTb = claTbArray{i};
    SL.ZZ.PlotCla(claTb, 'session');
    MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', .3);
    figName = "cla_" + predType + " " + claTb.sessionId{1};
    print(f, fullfile(figDir, figName), '-dpng', '-r0');
end


%% Pooled sequence type classification (by hierarhical bootstrap)

% Reload or compute
isOverwrite = false;

cacheName = ['cla_' predType '.mat'];
cachePath = fullfile(figDir, cacheName);
if exist(cachePath, 'file') && ~isOverwrite
    warning('%s has been computed and will not be overwritten', cacheName);
    load(cachePath);
else
    % Group classification results by condition
    mClaTb = SL.ZZ.GroupByConditions(claTbArray);
    
    for i = 1 : height(mClaTb)
        disp(['Compute for condition ' num2str(i)]);
        
        % Classification using hierarchical bootstrap resampling
        nBoot = 200;
        [rBoot, rShufBoot] = SL.Pop.HierBootClassify(nBoot, mClaTb.claTb{i});
        mClaTb.rBoot{i} = rBoot;
        mClaTb.rShufBoot{i} = rShufBoot;
        
        % Compute mean and CI
        a = 0.05;
        ciLims = [a/2 1-a/2] * 100;
        mClaTb.alpha(i) = a;
        mClaTb.rStats{i} = [mean(rBoot,2) prctile(rBoot, ciLims, 2)];
        mClaTb.rShufStats{i} = [mean(rShufBoot,2) prctile(rShufBoot, ciLims, 2)];
    end
    
    save(cachePath, 'mClaTb');
end


%% Plot overall classification accuracy

f = MPlot.Figure(40); clf
SL.ZZ.PlotCla(mClaTb, 'mean');
MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', .3);
saveFigurePDF(f, fullfile(figDir, "cla " + predType));


return

%% 

%         for m = 1 : height(cTb)
%             cTb.rStats{m} = [cTb.r{m} NaN(numel(cTb.r{m}), 2)];
%         end
%         cTb = movevars(cTb, 'rStats', 'Before', 'rShufStats');
%         disp('Save classification results');
%         save(cachePath, 'cTb');

%         % Compute pairwise state distances
%         ops.iShift = iShift;
%         ops.rsWin = [-.3 .3];
%         distTb = SL.Pop.SetDistMatrices(seTb, ops);
%     
%         % Compute mean stats of state distance
%         mdistTb = SL.Pop.MeanDist(distTb);


%% Plot single-trial PCA trajectories with time shift in 3D

t = seTb.time{1}(:,1,1);
ind = t > ops.rsWin(1) & t < ops.rsWin(2);
S1 = permute(seTb.pca{1}(ind,1:3,:), [1 3 2]);
ind = circshift(ind, iShift(1));
S2 = permute(seTb.pca{2}(ind,1:3,:), [1 3 2]);

MPlot.Figure(20); clf

plot3(S1(:,:,1), S1(:,:,2), S1(:,:,3), 'r'); hold on
plot3(S2(:,:,1), S2(:,:,2), S2(:,:,3), 'b');


%% Plot single-trial PC projections with time shift

MPlot.Figure(30); clf

for j = 1 : numel(iShift)
    
    t = seTb.time{1}(:,1,1);
%     ind = t > ops.rsWin(1) & t < ops.rsWin(2);
    ind = t > -1.5 & t < 1.5;
    t = t(ind);
    S1 = permute(seTb.pca{2}(ind,1:3,:), [1 3 2]);
    ind = circshift(ind, iShift(j));
    S2 = permute(seTb.pca{1}(ind,1:3,:), [1 3 2]);
    
    nPC = size(S1, 3);
    
    for i = 1 : nPC
        MPlot.Axes(2,3,(j-1)*nPC+i);
        plot(t, S1(:,:,i), 'r'); hold on
        plot(t, S2(:,:,i), 'b');
    end
end


%% Plot mean state distance as a function of time

MPlot.Figure(3); clf

t = mdistTb.time{1};
N = height(mdistTb);

for i = 1 : N
    MPlot.Axes(1,N,i);
    m = mdistTb.auto{i};
    plot(t, m(:,1), 'k'); hold on
    MPlot.ErrorShade(t, m(:,1), m(:,2), m(:,3), 'IsRelative', false);
    
    m = mdistTb.xSame{i};
    plot(t, m(:,1), 'b'); hold on
    MPlot.ErrorShade(t, m(:,1), m(:,2), m(:,3), 'IsRelative', false);
    
    m = mdistTb.xShifted{i};
    plot(t, m(:,1), 'r'); hold on
    MPlot.ErrorShade(t, m(:,1), m(:,2), m(:,3), 'IsRelative', false);
    
    xlabel('Time to mid-seq (s)')
    ylabel('Mean distance of PCA trajectories (AU)')
    % ylim([.3 .7]);
end


