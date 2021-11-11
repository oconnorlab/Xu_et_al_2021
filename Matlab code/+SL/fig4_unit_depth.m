%% Cluster distributions of unit as a function of cortical depth

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig4');


%% Load cached results

resultPath = fullfile(figDir, 'extracted nnmf.mat');
load(resultPath, 'unitTb', 'clustTb');


%% Plot cluster composition by depths

areaList = {'All', 'S1TJ', 'M1TJ', 'ALM'};
nArea = numel(areaList);

f = MPlot.Figure(825); clf

for i = 1 : nArea
    % Compute histograms
    N = SL.Unit.ClustSizeByDepth(unitTb, areaList{i});
    N = [N sum(N,2)];
    P = N ./ sum(N,1);
    nD = sum(N);
    
    % Show numbers
    disp(areaList{i});
    disp(N);
    
    ax = subplot(nArea,1,i);
    bar(P', 'stacked', 'EdgeColor', 'none');
%     text(1:6, -0.1*ones(1,6), string(nD), 'FontSize', 10, 'HorizontalAlignment', 'center');
    
    
    lg = legend('#1', '#2', '#3-6', '#8-11', '#12-13', '#7');
    lg.Location = 'eastoutside';
    lg.Box = 'off';
    lg.Title.String = 'Cluster ID';
    
    ax = MPlot.Axes(ax);
    ax.XLim = [.2 6.8];
    ax.YDir = 'reverse';
    ax.YLabel.String = 'Fraction';
    ax.XLabel.String = 'Cortical depth (um)';
    ax.XTickLabel = {'<400', '400-600', '600-800', '800-1000', '>1000', 'All depths'};
    ax.XTickLabelRotation = 45;
    ax.Title.String = areaList{i};
end

MPlot.Paperize(f, 'ColumnsWide', 0.53, 'ColumnsHigh', 0.4*nArea);
MPlot.SavePDF(f, fullfile(figDir, "nnmf cluster depth"));

%{
Updated on 7/21/2021

All
     3     9    33    23    34   102
     8     7    26    28    39   108
    25    48    76    87    93   329
    27    46    92    92   102   359
    10    28    45    41    51   175
     1     4    18    15     9    47

S1TJ
     1     0     7     4     0    12
     0     0     0     0     1     1
     2     9     8     5     4    28
     5     9    11     8     9    42
     1     5     5     3     3    17
     0     1     8     5     5    19

M1TJ
     1     3     6     9     9    28
     4     0     4     6     3    17
     7    10    17    17    19    70
     5    12    24    18     9    68
     0     9     9     5     9    32
     0     1     5     9     3    18

ALM
     1     2     8     5    14    30
     2     3    10    10    13    38
    10    17    17    38    33   115
    10     9    30    33    22   104
     2     3     9     6    12    32
     0     0     4     1     0     5
%}

