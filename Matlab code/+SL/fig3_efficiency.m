%% Analyze calibration of opto inhibition with Si recording

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig3');

% Find SEs
dataSource = SL.Data.FindSessions('fig3_efficiency');

% Metadata
% Needs to swap opto and recording sites for MX190101 2019-04-16,17,18 to get the code running correctly
% This is just a hack. The original metadata is correct.
xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');
xlsTb = SL.Data.SwapSites(xlsTb);

% Load SEs
seArray = SL.SE.LoadSession(dataSource.path);
xlsTb = SL.SE.AddXlsInfo2SE(seArray, xlsTb);


%% Preprocessing

% Transform SEs
ops = SL.Param.Transform;
ops.isSpkRate = false;
ops.alignType = 'mid';
ops.conditionVars = {'opto', 'optoMod1', 'optoDur1'};

seTbCell = cell(size(seArray));
for i = 1 : numel(seTbCell)
    se = seArray(i).Duplicate;
    seTb = SL.SE.Transform(se, ops);
    isInclude = ismember(seTb.opto, [-1 1]) & ismember(seTb.optoDur1, [0 2]);
    seTb(~isInclude,:) = [];
    seTbCell{i} = seTb;
end

% Group sessions by configuration
cfTb = table();
cfTb.recArea = cellfun(@(x) x.se(1).userData.xlsInfo.target_area, seTbCell, 'Uni', false);
cfTb.optoArea = cellfun(@(x) x.se(1).userData.xlsInfo.opto_area, seTbCell, 'Uni', false);
[groupId, cfTb] = findgroups(cfTb);
cfTb.seTb = splitapply(@(x) {vertcat(x{:})}, seTbCell, groupId);

% Combine opto conditions
for i = 1 : height(cfTb)
    seTb = cfTb.seTb{i};
    optoMod = [0 0.125 0.25 0.5 1]'; %unique(seTb.optoMod1)
    conds = array2table(optoMod, 'VariableNames', {'optoMod1'});
    seTb = SL.SE.CombineConditions(conds, seTb);
    cfTb.seTb{i} = seTb;
end


%% Compute spike rates and normalize unit waveform

% Processing parameters
ops.rsWin = [0 2];

% For each configuration (i.e. distance)
for i = 1 : height(cfTb)
    seTb = cfTb.seTb{i};
    
    % For each opto power
    for j = 1 : height(seTb)
        % Initialize tables with unit info
        uoTbCell = arrayfun(@SL.Unit.UnitInfo, seTb.se{j}, 'Uni', false);
        
        % For each session
        for k = 1 : numel(seTb.se{j})
            se = seTb.se{j}(k);
            
            % Compute spike rate for each trial
            rTb = se.ResampleEventTimes('spikeTime', ops.rsWin);
            rMat = cell2mat(rTb{:,2:end});
            
            % Compute mean spike rate
            [m, ~, e] = MMath.MeanStats(rMat); % no bootstrap
            
            uoTbCell{k}.rMean = m';
            uoTbCell{k}.rSE = e';
        end
        uoTb = vertcat(uoTbCell{:});
        
        seTb.rMean(j,:) = uoTb.rMean';
        seTb.rSE(j,:) = uoTb.rSE';
    end
    cfTb.rMean{i} = seTb.rMean';
    cfTb.rSE{i} = seTb.rSE';
    
    % Construct grouping matrix
    cfTb.gInd{i} = [findgroups(uoTb.animalId), findgroups(uoTb.sessionDateTime), uoTb.unitNum];
    
    % Get unit depth
    cfTb.depth{i} = uoTb.depth;
    
    % Normalize unit spike waveform by negative peak
    wf = cell2mat(uoTb.meanWaveform)';
    wf = wf - median(wf);
    wf = wf ./ max(abs(wf));
    cfTb.wf{i} = wf';
    
    [vNeg, iNeg] = min(wf);
    for j = 1 : numel(iNeg)
        wf(1:iNeg(j),j) = -Inf;
    end
    [vPos, iPos] = max(wf);
    cfTb.tPk2Pk{i} = abs(iPos-iNeg)' / 30; % peak-to-peak time in ms
end


%% Validate selection criteria

f = MPlot.Figure(32139); clf

% Compare pyramidal vs FS waveform
wf = cell2mat(cfTb.wf);
tPk2Pk = cell2mat(cfTb.tPk2Pk);
tCut = SL.Param.fsPyrCutoff;
isFS = tPk2Pk < tCut(1);
isPyr = tPk2Pk > tCut(2);

subplot(1,3,1);
plot(wf(isPyr,:)', 'Color', [0 0 0 .15]); hold on
plot(wf(isFS,:)', 'Color', [0 0 1 .15]);
plot(1+[0 15], [0 0]-.7, 'k', 'LineWidth', 2); % 0.5 ms scale bar
axis tight off

% Spike width histograms
iS1 = 3;
tPk2PkS1 = cfTb.tPk2Pk{iS1};

subplot(1,3,2);
histogram(tPk2Pk, 0:0.05:1.1, 'FaceColor', 'w'); hold on
histogram(tPk2PkS1, 0:0.05:1.25, 'FaceColor', 'k');
plot(tCut([1 1]), [0 100], '--', 'Color', [0 0 0 .5]);
plot(tCut([2 2]), [0 100], '--', 'Color', [0 0 0 .5]);
xlim([0 1.1]);
ylim([0 100]);
xlabel('Trough to peak time (ms)')
ylabel('# of units');

% Spike rate change against spike width
isFS = tPk2PkS1 < tCut(1);
isPyr = tPk2PkS1 > tCut(2);
mm = cfTb.rMean{iS1};
dmm = mm(:,end) ./ mm(:,1);
dmm = max(dmm, 1e-3);

ax = subplot(1,3,3);
plot(tPk2PkS1(isFS), dmm(isFS), 'bo'); hold on
plot(tPk2PkS1(~isPyr & ~isFS), dmm(~isPyr & ~isFS), 'o', 'Color', [0 0 0]+.7);
plot(tPk2PkS1(isPyr), dmm(isPyr), 'ko');
plot([0 1], [1 1], '-', 'Color', [0 0 0 .5]);
plot(tCut([1 1]), [1e-3 1e3], '--', 'Color', [0 0 0 .5]);
plot(tCut([2 2]), [1e-3 1e3], '--', 'Color', [0 0 0 .5]);
xlabel('Trough to peak time (ms)')
ylabel('Relative spike rate');
ax.YScale = 'log';
ax.YLim = [1e-3 .5e3];
ax.YTick = [1e-3 1 .5e3];

MPlot.Paperize(f, 'ColumnsWide', 1.2, 'ColumnsHigh', .3);
MPlot.SavePDF(f, fullfile(figDir, "FS vs pyramidal"));


%% Compute efficiency stats

cachePath = fullfile(figDir, 'computed efficiency.mat');

if exist(cachePath, 'file')
    load(cachePath);
else
    [effPyr, bootPyr] = SL.Opto.ComputeEfficiencyCurves(cfTb, 'Pyr');
    [effFS, bootFS] = SL.Opto.ComputeEfficiencyCurves(cfTb, 'FS');
    save(cachePath, 'effPyr', 'bootPyr', 'effFS', 'bootFS');
end


%% Plot efficiency

f = MPlot.Figure(32159); clf

[nPower, ~, nDist] = size(effPyr);
mW = cfTb.seTb{1}.optoMod1*16*.5; % 16mW, 50% duty-clcle, no need to include the 50% transmission
cc = winter(nDist);
dists = ["~ 3", "~ 1.5", "< 1"] + " mm";


subplot(2,1,1)
for i = 1 : height(cfTb)
    x = (1:nPower)'+i*.1-.2;
    m = effPyr(:,1,i);
    sem = effPyr(:,2,i);
    ci = effPyr(:,3:4,i);
%     errorbar(x, m, sem, 'Color', cc(i,:)); hold on
    errorbar(x, m, m-ci(:,1), ci(:,2)-m, 'Color', cc(i,:)); hold on
end

ax = MPlot.Axes(gca);
ax.YLim = [-0.1 1.1];
ax.XLim = [.8 nPower+.2];
ax.XTick = 1:nPower;
ax.XTickLabel = mW;
xlabel("Power (mW)");
ylabel('Relative spike rate');
% title("Stim at " + cfTb.optoArea{1});
% legend("Rec at " + cfTb.recArea, 'Location', 'eastoutside', 'Box', 'off');
legend(dists, 'Location', 'eastoutside', 'Box', 'off');


subplot(2,1,2)
for i = 1 : height(cfTb)
    x = (1:nPower)'+i*.1-.2;
    m = effFS(:,1,i);
    sem = effFS(:,2,i);
    ci = effFS(:,3:4,i);
%     errorbar(x, m, sem, 'Color', cc(i,:)); hold on
    errorbar(x, m, m-ci(:,1), ci(:,2)-m, 'Color', cc(i,:)); hold on
end

ax = MPlot.Axes(gca);
ax.YScale = 'log';
ax.YLim = [.5 30];
ax.YTick = [1 10];
ax.XLim = [.8 nPower+.2];
ax.XTick = 1:nPower;
ax.XTickLabel = mW;
xlabel("Power (mW)");
ylabel('Relative spike rate');
% title("Stim at " + cfTb.optoArea{1});
% legend("Rec at " + cfTb.recArea, 'Location', 'eastoutside', 'Box', 'off');
legend(dists, 'Location', 'eastoutside', 'Box', 'off');

MPlot.Paperize(f, 'ColumnsWide', 0.6, 'ColumnsHigh', .6);
MPlot.SavePDF(f, fullfile(figDir, "efficiency curves"));


% Report number of units included
fileID = fopen(fullfile(figDir, 'opto efficiency.txt'), 'w');

fprintf(fileID, 'A total of %g units\n', sum(cellfun(@numel, cfTb.tPk2Pk)));
fprintf(fileID, 'A total of %g Pyr units\n', sum(effPyr(1,5,:)));
fprintf(fileID, 'A total of %g FS units\n\n', sum(effFS(1,5,:)));

iPower = 5;
for i = 1 : nPower
    for j = 1 : numel(dists)
        fprintf(fileID, '%s\t n = %g Pyr units\t %.2f reduction at %.1fmW\n', ...
            dists(j), effPyr(i,5,j), 1-effPyr(i,1,j), mW(i));
        fprintf(fileID, '%s\t n = %g FS units\t %.2f reduction at %.1fmW\n', ...
            dists(j), effFS(i,5,j), 1-effFS(i,1,j), mW(i));
    end
    fprintf(fileID, '\n');
end

fclose(fileID);

