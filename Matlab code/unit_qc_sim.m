%% Simulation of unit contamination

figure(123); clf

% Parameters
c = 0.05;
F = 1;
N = 1e5;
isiLim = 0.0025;

% True spikes
isiSpk = exprnd(1/(F*(1-c)), [1 N*2]);
isiSpk(isiSpk < isiLim) = [];
isiSpk = isiSpk(1:N*(1-c));
tSpk = cumsum(isiSpk);
isiCountSpk = histcounts(isiSpk, 0:0.0005:0.05);

% Noise
isiNoi = exprnd(1/(F*c), [1 N*c]);
tNoi = cumsum(isiNoi);

% Mixing
tMix = sort([tSpk tNoi]);
% tMix = tSpk;


% ISI
isiMix = diff(tMix);
p = sum(isiMix < isiLim) / numel(isiMix);
isiCount = histcounts(isiMix, 0:0.0005:0.05);

subplot(1,2,1);
bar((.5:.5:50)'-.25, isiCount, 1, 'EdgeColor', 'none');
axis tight
xlabel('ISI (ms)');
title(sprintf('ISI histogram (p = %.2g%%)', p*100));


% ACG
acg = MNeuro.CCG(-0.05:0.0005:0.05, tMix);
acg = squeeze(acg);
acg = acg(101:end);

subplot(1,2,2);
bar((.5:.5:50)'-.25, acg, 1, 'EdgeColor', 'none')
axis tight
xlabel('Pairwise spike inteval (ms)');
title('ACG');


%%

F = 1:40;
p = 0:1e-4:1e-2;
c = MNeuro.ClusterContamination(p', F, 0.002, 0.00075);

figure(234); clf

subplot(2,1,1);
cInd = 2.^(0:4);
plot(p'*100, c(:,cInd)*100);
xlabel('ISI violation (%)');
ylabel('Contamination (%)');
legend(arrayfun(@(x) [num2str(x) 'Hz; ' num2str(x*4000) 'spk/~60min'], F(cInd), 'Uni', false), ...
    'Location', 'eastoutside');
grid on

subplot(2,1,2);
plot(F', c([3 21 101],:)*100);
xlabel('Firing rate (Hz)');
ylabel('Contamination (%)');
legend(arrayfun(@(x) [num2str(x*100) '%'], p([3 21 101]), 'Uni', false), ...
    'Location', 'eastoutside');
grid on

