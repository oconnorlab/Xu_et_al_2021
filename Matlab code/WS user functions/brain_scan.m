function v = brain_scan(i, axId)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

% Make coordinates
s = 0.5; % spacing in mm

L = { ... % posterior to anterior
    0.5 : s : 5, ...    % B -1
    0.5 : s : 4.5, ...  % B -0.5
    0.5 : s : 4.5, ...  % B 0
    0.5 : s : 4, ...    % B 0.5
    0.5 : s : 4, ...    % B 1
    0.5 : s : 3.5, ...  % B 1.5
    0.5 : s : 3, ...    % B 2
    0.5 : s : 2.5, ...  % B 2.5
    0.5 : s : 2, ...    % B 3
    }; 

B_levels = -1 : s : 3;
B = cell(size(L));
for k = 1 : numel(L)
    B{k} = repmat(B_levels(k), size(L{k}));
end

L = [L{:}];
B = [B{:}];

% plot(locL', locB', '-o')

% Wrap index
i = i - 1;
i = mod(i, numel(L));
i = i + 1;

% Randomization
rng('default');
randList = randsample(numel(B), numel(B));
i = randList(i);

% Convert to output
voltPerMm = 1;
offsetL = 0; % in mm
offsetB = 0; % in mm

if axId == 1
    v = (L(i) + offsetL) * voltPerMm;
else
    v = (B(i) + offsetB) * voltPerMm;
end

end

