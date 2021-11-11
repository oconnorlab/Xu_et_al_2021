%% Quantify oscillation in PETH

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig4');


%% Load cached results

resultPath = fullfile(figDir, 'extracted nnmf.mat');
load(resultPath, 'unitTb', 'clustTb');


%% Fit sinusoids to PETHs

% Set up parameters and options
periods = [3 4]; % only including Mid sequences
nPeriod = numel(periods);

ft = fittype('a*sin(2*pi*6.5*x+b)+c', 'independent', 'x', 'dependent', 'y');
opts = fitoptions('Method', 'NonlinearLeastSquares');
opts.Display = 'Off';
opts.StartPoint = [0.492467604027446 0.393804561348837 0.286200548291097]; % for reproducibiliy

rTb = table;
rTb.areaName = {'S1TJ', 'M1TJ', 'ALM'}';
rTb.areaColor = SL.Param.GetAreaColors(rTb.areaName);
for a = 1 : height(rTb)
    %
    disp(rTb.areaName{a});
    isArea = strcmp(unitTb.areaName, rTb.areaName{a});
    subTb = unitTb(isArea,:);
    
    [nUnit, nTime] = size(subTb.hh1);
    T = zeros(nUnit, nTime, nPeriod);
    H = T;
    S = T;
    R = zeros(nUnit, nPeriod); % adjusted R-squared
    C = zeros(nUnit, nPeriod); % correlation coefficients
    for i = 1 : nPeriod
        p = periods(i);
        disp(['Period ' num2str(p)])
        T(:,:,i) = subTb.(['tt' num2str(p)]);
        H(:,:,i) = subTb.(['hh' num2str(p)]);
        for u = 1 : nUnit
            % Fit model to data
            t = T(u,:,i)';
            h = H(u,:,i)';
            [fobj, gof] = fit(t, h, ft, opts);
            R(u,i) = gof.adjrsquare;
            
            % Compute correlation coefficient between PETH and sine
            s = feval(fobj, t);
            S(u,:,i) = s;
            C(u,i) = corr(h, s);
        end
    end
    rTb.time{a} = T;
    rTb.PETH{a} = H;
    rTb.sinusoid{a} = S;
    rTb.r2{a} = R;
    rTb.coeff{a} = C;
    [rTb.maxCoeff{a}, rTb.maxPeriod{a}] = max(C, [], 2); % Find the maximum correlation from the two directions
end


%% Example units

f = MPlot.Figure(585519); clf
k = 0;
for a = 1 : height(rTb)
    %
    area = rTb.areaName{a};
    isArea = strcmp(unitTb.areaName, area);
    subTb = unitTb(isArea,:);
    
    % Find examples
    eg = SL.UnitFig.GetExampleInfo(area);
    sessionIds = cellfun(@(x,y) [x ' ' datestr(y, 'yyyy-mm-dd')], subTb.animalId, num2cell(subTb.sessionDateTime), 'Uni', false);
    isSess = strcmp(sessionIds, eg.sessionDatetime);
    unitNums = subTb.unitNum;
    unitNums(~isSess) = NaN;
    egInd = zeros(size(eg.unitInd));
    for i = 1 : numel(eg.unitInd)
        egInd(i) = find(unitNums == eg.unitInd(i), 1);
    end
    rTb.egInd{a} = egInd;
    
    % Plot
    for i = 1 : numel(egInd)
        u = egInd(i);
        cPeriod = [SL.Param.RLColor; SL.Param.LRColor];
        for j = 1 : nPeriod
            t = rTb.time{a}(u,:,j);
            h = rTb.PETH{a}(u,:,j);
            s = rTb.sinusoid{a}(u,:,j);
            r = rTb.coeff{a}(u,j);
            k = k + 1;
            ax = subplot(3,6,k);
            plot(t, h, 'k'); hold on
            plot(t, s, 'Color', cPeriod(j,:));
            xlim(t([1 end]));
            ylim([0 max([h s])]);
            xlabel('Time from Mid (s)');
            ylabel('r (spk/s)');
            title([area ' u:' num2str(i) ' r:' num2str(r, '%.2f')]);
            MPlot.Axes(ax);
        end
    end
end
MPlot.Paperize(f, 'ColumnsWide', 2, 'Aspect', .4);
MPlot.SavePDF(f, fullfile(figDir, 'corr of example units'));


%% CDFs of periodicity

f = MPlot.Figure(585520); clf
for a = 1 : height(rTb)
    % Compute and plot CDF
%     x = 0 : .01 : 1;
%     y = histcounts(rTb.maxCoeff{a}, x, 'Normalization', 'cdf');
%     y = y([1 1:end]);
    x = sort(rTb.maxCoeff{a});
    y = (1 : numel(x))' ./ numel(x);
    stairs(x, y, 'Color', rTb.areaColor(a,:));hold on
    
    % Mark example units
    egCoeff = rTb.maxCoeff{a}(rTb.egInd{a});
    egInd = find(ismember(x, egCoeff));
    plot(x(egInd), y(egInd), 'o', 'Color', rTb.areaColor(a,:));
end
ax = gca;
ax.XLim = [0 1];
ax.XTick = 0:.2:1;
ax.YLim = [0 1];
ax.YTick = 0:.2:1;
xlabel('r');
ylabel('Fraction of units');
title('Correlation w/ 6.5Hz sinusoid');
% legend(rTb.areaName, 'Location', 'southeast');
MPlot.Axes(gca);
MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', .33);
MPlot.SavePDF(f, fullfile(figDir, 'corr cdf'));

