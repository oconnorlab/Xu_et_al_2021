%% Get unit info

% Basic unit info
unitTb = SL.Unit.UnitInfo(se);

% Convert channel indices to tetrode and wire indicies
unitTb.tetrodeInd = ceil(unitTb.chanInd ./ 4);
unitTb.wireInd = mod(unitTb.chanInd-1, 4);
unitTb.chanLabel = arrayfun(@(x,y) ['Electrode #' num2str(x+y*0.1, '%1.1f')], ...
    unitTb.tetrodeInd, unitTb.wireInd, 'Uni', false);


%% Prepare spike trains

% Concatenate pre-training and main spike time tables
spkTb = [se.userData.spikeInfo.preTaskET; se.GetTable('spikeTime')];
rt = [0; se.GetReferenceTime()];

% Convert relative spike times to absolute times
for i = 1 : height(spkTb)
    for j = 1 : width(spkTb)
        spkTb.(j){i} = spkTb.(j){i} + rt(i);
    end
end

% Concatenate trials of spike times to a single spike train for each unit
spkTrains = cell(1, width(spkTb));
for i = 1 : width(spkTb)
    spkTrains{i} = cell2mat(spkTb.(i));
end


%% CCG

% Histogram time bins
tEdges = -0.025 : 1e-3 : 0.025;

% Compute CCGs
ccg = MNeuro.CCG(tEdges, spkTrains{:});


%% Plot waveforms and firing history

f = figure(98745543);
f.Color = 'w';

nRow = height(unitTb);
nCol = 10;

% Plot unit info
for i = 1 : nRow
    % Prepare spike waveforms
    W = spike_waveforms{i};
    meanW = mean(W);
    prctW = prctile(W, [15 85], 1);
    ind = randsample(size(W,1), 200);
    
    % Plot waveforms
    subplot(nRow, nCol, (i-1)*nCol+1); cla
    hold on
    
    plot(W(ind,:)', 'Color', [0 0 0 .03]);
    plot(meanW, 'r');
    plot(prctW(1,:), 'r--');
    plot(prctW(2,:), 'r--');
    plot([0 0]'-3, [-100 100]', 'k', 'LineWidth', 2);
    
    title(unitTb.chanLabel{i});
    box off;
    axis tight off
    maxVal = max([abs(meanW) 100]);
    ylim([-maxVal maxVal] * 1.5);
    
    % Prepare histogram
    ax = subplot(nRow, nCol, (i-1)*nCol+2:i*nCol); cla
    
    histogram(spkTrains{i}, 0:10:info.rec_time, ...
        'Normalization', 'countdensity', 'EdgeColor', 'none');
    
    xlim([0 info.rec_time]);
    ylabel('spk/s');
    ax.TickLength(1) = 0;
    ax.Box = 'off';
end

% Save figure as PDF
% saveFigurePDF(gcf, 'new figure 1.pdf');


%% Plot CCGs

f = figure(98745544);
f.Color = 'w';

nRow = size(ccg, 1);
nCol = size(ccg, 2);

tCenters = tEdges(1:end-1) + diff(tEdges(1:2))/2;
for i = 1 : nRow
    for j = i : nCol
        subplot(nRow, nCol, (i-1)*nCol+j); cla
        
        % Full CCG
        bar(tCenters, squeeze(ccg(i,j,:)), 1, ...
            'EdgeColor', 'none');
        hold on;
        
        if i == j
            % Highlight ISI violated portion
            isRP = abs(tCenters) <= 0.0025;
            bar(tCenters(isRP), squeeze(ccg(i,j,isRP)), 1, ...
                'EdgeColor', 'none', 'FaceColor', 'r');
            
            title(unitTb.chanLabel{i});
        end
        
        hold off
        axis off
    end
end

% Shrink font size
MPlot.Paperize(f);

% Save figure as PDF
% saveFigurePDF(gcf, 'new figure 2.pdf');




