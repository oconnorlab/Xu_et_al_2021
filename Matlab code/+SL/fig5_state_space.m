%% Linear decoding of behavioral variables

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig5');


%% Load cached decoding results

areaList = {'S1TJ', 'M1TJ', 'ALM', 'S1BF'};
decTb = cell(size(areaList));
for a = 1 : numel(areaList)
    cachePath = fullfile(figDir, ['dec seq-seq-seq ' areaList{a}]);
    decTb{a} = load(cachePath);
end
decTb = cat(1, decTb{:});
decTb = struct2table(decTb);


%%

for i = 1 : height(decTb)
    varInd = 3:5;
    decTb.cch{i} = SL.Pop.CanonCorr(decTb.comTb{i}, varInd);
    varInd = 1:3;
    decTb.ccl{i} = SL.Pop.CanonCorr(decTb.comTb{i}, varInd);
    varInd = 1:5;
    decTb.ccf{i} = SL.Pop.CanonCorr(decTb.comTb{i}, varInd);
end

cchM2 = decTb.cch{1};
t = cchM2.t;
tMask = t>-0.45 & t<0.75;
id = cchM2.id;
colorReg = [0 0 1; 1 0 0];
colorPCA = MMath.Bound(colorReg, [.6 1]);


%% 

f = MPlot.Figure(14755); clf

nArea = 3;

for i = 1 : nArea
    r = [decTb.ccl{i}.mr decTb.cch{i}.mr decTb.ccf{i}.mr];
    xx = repmat([i-.25 i i+.25], size(r,1), 1);
    mr = mean(r);
    plot(xx', r', '-', 'Color', [0 0 0 .3], 'LineWidth', .5); hold on
    plot(xx(1,:)', mr', '-', 'Color', [0 0 0], 'LineWidth', 1);
    
    p = SL.Pop.PairwiseTest(r, 'perm', 'paired');
    disp(decTb.areaName{i});
    disp(p);
end

ylabel('Mean r');
ax = MPlot.Axes(gca);
ax.XLim = [.4 nArea+.6];
ax.YLim = [.2 1];
ax.XTick = 1 : nArea;
ax.XTickLabel = decTb.areaName(1:nArea);
ax.YTick = .2 : .2 : 1;

lg = legend('L,L'',\theta w PC1-3', '\theta,I,\tau w PC1-3', 'Full w PC1-5');
lg.Location = 'northoutside';
lg.Box = 'off';

MPlot.Paperize(f, 'ColumnsWide', .33, 'AspectRatio', 1);
saveFigurePDF(f, fullfile(figDir, "state similarity"));

%{
S1TJ
       NaN    0.0001    0.0327
       NaN       NaN    0.0001
       NaN       NaN       NaN

M1TJ
       NaN    0.3205    0.0302
       NaN       NaN    0.0019
       NaN       NaN       NaN

ALM
       NaN    0.0003    0.0001
       NaN       NaN    0.0003
       NaN       NaN       NaN
%}


%% 

f = MPlot.Figure(19754); clf

% camPos = [120 -3.5 5];
camPos = [120 -2.7 2];

% 
subplot(1,3,1);

cchM2 = decTb.cch{1};
X = cchM2.mX;
Xtf = cchM2.mY2X;
SL.PopFig.PlotStateTraj(X, id, tMask, colorReg);
SL.PopFig.PlotStateTraj(Xtf, id, tMask, colorPCA);

X(:,3) = -.4;
Xtf(:,3) = -.4;
SL.PopFig.PlotStateTraj(X, id, tMask, colorReg, .5);
SL.PopFig.PlotStateTraj(Xtf, id, tMask, colorPCA, .5);

xlabel('\theta');
ylabel('I');
zlabel('\tau');
grid on
ax = MPlot.Axes(gca);
ax.XLim = [-18 18];
ax.YLim = [-.6 .6];
ax.ZLim = [-.4 .35];
ax.XTick = [ax.XLim(1) 0 ax.XLim(2)];
ax.YTick = [ax.YLim(1) 0 ax.YLim(2)];
ax.ZTick = [ax.ZLim(1) 0 ax.ZLim(2)];
ax.TickLength = [0 0];
ax.CameraPosition = camPos;


% 
subplot(1,3,2);

cclM1 = decTb.ccl{2};
X = cclM1.mX;
SL.PopFig.PlotStateTraj(X, id, tMask, colorReg);
X(:,3) = -30;
SL.PopFig.PlotStateTraj(X, id, tMask, colorReg, .5);

xlabel('L');
ylabel('L''');
zlabel('\theta');
grid on
ax = MPlot.Axes(gca);
ax.XLim = [.2 2.2];
ax.YLim = [-60 80];
ax.ZLim = [-30 20];
ax.XTick = [ax.XLim(1) ax.XLim(2)];
ax.YTick = [ax.YLim(1) 0 ax.YLim(2)];
ax.ZTick = [ax.ZLim(1) 0 ax.ZLim(2)];
ax.TickLength = [0 0];
% ax.CameraPosition = [160 -3.8 4];


% 
subplot(1,3,3);

X = cchM2.mX;
SL.PopFig.PlotStateTraj(X, id, tMask, colorReg);
X(:,1:2) = X(:,1:2) + zscore(cclM1.mX(:,1:2)).*[3 .15];
SL.PopFig.PlotStateTraj(X, id, tMask, colorReg, .5);

% X = cchM2.mX;
% X(:,3) = -.4;
% SL.PopFig.PlotStateTraj(X, id, tMask, colorReg, .5);
% X(:,1:2) = X(:,1:2) + zscore(cclM1.mX(:,1:2)).*[3 .15];
% SL.PopFig.PlotStateTraj(X, id, tMask, colorReg, .5);

xlabel('\theta');
ylabel('I');
zlabel('\tau');
grid on
ax = MPlot.Axes(gca);
ax.XLim = [-18 18];
ax.YLim = [-.6 .6];
ax.ZLim = [-.4 .35];
ax.XTick = [ax.XLim(1) 0 ax.XLim(2)];
ax.YTick = [ax.YLim(1) 0 ax.YLim(2)];
ax.ZTick = [ax.ZLim(1) 0 ax.ZLim(2)];
ax.TickLength = [0 0];
ax.CameraPosition = camPos;


MPlot.Paperize(f, 'ColumnsWide', 1.6, 'AspectRatio', .25);
saveFigurePDF(f, fullfile(figDir, "state trajectories"));


return

%% 

% Initialize array using theta, I and tau from ALM
[M2, id, t] = SL.PopFig.GetSchemProj(decTb.mcomTb{1}(1:2,:), 3:5);

isRL = ismember(id, {'123456', '1231456'});
isLR = ismember(id, {'543210', '5435210'});
isN = ismember(id, {'123456', '543210'});
isB = ismember(id, {'1231456', '5435210'}) & t > 0;

% Get L and L'
M1 = SL.PopFig.GetSchemProj(decTb.mcomTb{2}, 1:2);

% Blend L and L' into I and tau
MM = M2;
r = .2;
R = roty(-45);
MM(isRL,:) = M2(isRL,:) + (R*M1(isRL,:)')'.*r;
R = roty(45);
MM(isLR,:) = M2(isLR,:) + (R*M1(isLR,:)')'.*r;


%% 

% Plot state trajectories
f = MPlot.Figure(99); clf

% subplot(2,1,1);
ccReg = lines(2);

x = M2(isRL & isN, 1);
y = M2(isRL & isN, 2);
z = M2(isRL & isN, 3);
plot3(x, y, z, 'Color', ccReg(1,:), 'LineWidth', 1.5);
hold on

x = M2(isLR & isN, 1);
y = M2(isLR & isN, 2);
z = M2(isLR & isN, 3);
plot3(x, y, z, 'Color', ccReg(2,:), 'LineWidth', 1.5);

x = MM(isRL & isN, 1);
y = MM(isRL & isN, 2);
z = MM(isRL & isN, 3);
plot3(x, y, z, 'Color', ccReg(1,:), 'LineWidth', .5);
hold on

x = MM(isLR & isN, 1);
y = MM(isLR & isN, 2);
z = MM(isLR & isN, 3);
plot3(x, y, z, 'Color', ccReg(2,:), 'LineWidth', .5);

% x = M2(isRL & isB, 1);
% y = M2(isRL & isB, 2);
% z = M2(isRL & isB, 3);
% plot3(x, y, z, ':', 'Color', cc(1,:), 'LineWidth', 1.5);
% 
% x = M2(isLR & isB, 1);
% y = M2(isLR & isB, 2);
% z = M2(isLR & isB, 3);
% plot3(x, y, z, ':', 'Color', cc(2,:), 'LineWidth', 1.5);

xlabel('\theta');
ylabel('I');
zlabel('\tau');
axis equal
grid on
ax = MPlot.Axes(gca);
ax.CameraPosition = [-12 16 18];
% ax.XLim = [-2 2];
% ax.YLim = [-2 2];


% subplot(2,1,2);
% 
% plot(t, M2(:,:));


% MPlot.Paperize(f, 'ColumnsWide', .35, 'AspectRatio', 3.3);
% saveFigurePDF(f, fullfile(figDir, "projections " + decTb.areaName{a}));




