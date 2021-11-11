%% Sequence tiling of PETH peaks

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig4');


%% Load cached results

resultPath = fullfile(figDir, 'extracted nnmf.mat');
load(resultPath, 'unitTb');


%% 

pkTb = table;
pkTb.areaName = {'S1TJ', 'M1TJ', 'ALM'}';
pkTb.areaColor = SL.Param.GetAreaColors(pkTb.areaName);
for a = 1 : height(pkTb)
    %
    disp(pkTb.areaName{a});
    isArea = strcmp(unitTb.areaName, pkTb.areaName{a});
    subTb = unitTb(isArea,:);
    
    % Make unit-by-time-by-direction arrays for timestamps and responses
    % time contactenates three periods of each direction
    nameFun = @(v,n) arrayfun(@(i) [v num2str(i)], n, 'Uni', false);
    T = cat(3, subTb{:,nameFun('tt', 1:2:5)}, subTb{:,nameFun('tt', 2:2:6)});
    R = cat(3, subTb{:,nameFun('hh', 1:2:5)}, subTb{:,nameFun('hh', 2:2:6)});
    
    % Make an array of mask of peak responses
    M = false(size(T));
    [~, pkInd2] = max(R, [], 2);
    pkInd1 = cumsum(ones(size(pkInd2)), 1);
    pkInd3 = cumsum(ones(size(pkInd2)), 3);
    pkInd = sub2ind(size(M), pkInd1, pkInd2, pkInd3);
    M(pkInd) = true;
    
    % Split data into period-by-direction cell arrays
    [nUnit, nTime, nDir] = size(M);
    nPeriodPerDir = 3;
    nTime = nTime / nPeriodPerDir;
    T = squeeze(mat2cell(T, nUnit, nTime*ones(1,nPeriodPerDir), ones(1,nDir)));
    R = squeeze(mat2cell(R, nUnit, nTime*ones(1,nPeriodPerDir), ones(1,nDir)));
    M = squeeze(mat2cell(M, nUnit, nTime*ones(1,nPeriodPerDir), ones(1,nDir)));
    pkTb.time{a} = T;
    pkTb.resp{a} = R;
    pkTb.pkMask{a} = M;
    
    % Extract peaks
    pkTb.pkTime{a} = cellfun(@(t,m) t(m), T, M, 'Uni', false);
    pkTb.pkResp{a} = cellfun(@(r,m) r(m), R, M, 'Uni', false);
end


%% 

f = MPlot.Figure(155970); clf

nArea = height(pkTb);

for i = 1 : nPeriodPerDir*nDir
    ax = subplot(nDir, nPeriodPerDir, i);
    for a = 1 : nArea
        tPk = pkTb.pkTime{a}{i};
        rPk = pkTb.pkResp{a}{i};
%         plot(tPk, rPk, '.', 'Color', pkTb.areaColor(a,:)); hold on
        
        tt = pkTb.time{a}{i};
        tEdges = round(tt(1),1) : 0.2 : round(tt(end),1);
        tCenters = tEdges(2:end) - diff(tEdges)/2;
        nPk = histcounts(tPk, tEdges);
        nPk = nPk / size(tt,1);
%         stairs(tEdges, nPk([1:end end]), 'Color', pkTb.areaColor(a,:)); hold on
        plot(tCenters, nPk, '-', 'Color', pkTb.areaColor(a,:)); hold on
    end
    ax.XLim = tEdges([1 end]);
%     ax.XLim = tCenters([1 end]);
    ax.YLim = [0 .2];
    ax.XGrid = 'on';
    xlabel('Time (s)');
    ylabel('P(peak)');
    MPlot.Axes(ax);
end

MPlot.Paperize(f, 'ColumnsWide', .9, 'ColumnsHigh', 0.4);
saveFigurePDF(f, fullfile(figDir, 'tiling'));

