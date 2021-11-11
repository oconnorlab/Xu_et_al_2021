function s = sl_get_specs(animalId, sessionDatetime, subId)
%SL_GET_SPECS Summary of this function goes here
%   Detailed explanation goes here

sessionId = [animalId, ' ', datestr(sessionDatetime, 'yyyy-mm-dd'), ' ', subId];
sessionId = strtrim(sessionId);

% Default specifications
s.satTrialNum = [];
s.hsvTrialNum = [];
s.intanTrialNum = [];
s.chanMap = MKilosort.chanMapH3;       % assume H3 probe

% Overwrite parameters based on specific group, animal and session
if any(strcmp(animalId, {'MX180802'}))
    s.chanMap = MKilosort.chanMapTetrode32;
end

if strcmp(sessionId, 'MX180701 2018-09-22')
    warning('%s: exclude timeout trials and the last trial.', sessionId);
    s.satTrialNum = [1:124 126:141];
    s.intanTrialNum = [1:124 126:141];
    s.hsvTrialNum = [1:124 126:141];
elseif strcmp(sessionId, 'MX180803 2018-11-28')
    warning('%s: StreamPix crashed after trial 359.', sessionId);
    s.satTrialNum = 1 : 359;
    s.intanTrialNum = 1 : 359;
    s.hsvTrialNum = [];
elseif strcmp(sessionId, 'MX181002 2018-10-23')
    warning('%s: missing high-speed video of the second trial.', sessionId);
    s.satTrialNum = 3 : 314;
    s.intanTrialNum = 3 : 314;
    s.hsvTrialNum = 2 : 313;
elseif strcmp(sessionId, 'MX181302 2019-02-01')
    warning('%s: StreamPix missed trial 227.', sessionId);
    s.satTrialNum = [1:226 228:273];
    s.intanTrialNum = [1:226 228:273];
    s.hsvTrialNum = [];
elseif strcmp(sessionId, 'MX181302 2019-02-02')
    warning('%s: units only stable after around the 58th trial.', sessionId);
    s.satTrialNum = 58 : 123;
    s.intanTrialNum = 58 : 123;
    s.hsvTrialNum = 58 : 123;
elseif strcmp(sessionId, 'MX190103 2019-05-15')
    warning('%s: units only stable in the first ~200 trials.', sessionId);
    s.satTrialNum = 1 : 200;
    s.intanTrialNum = 1 : 200;
    s.hsvTrialNum = 1 : 200;
elseif strcmp(sessionId, 'MX181301 2019-05-25')
    warning('%s: units only stable since trial 41.', sessionId);
    s.satTrialNum = 41 : 195;
    s.intanTrialNum = 41 : 195;
    s.hsvTrialNum = 41 : 195;
elseif strcmp(sessionId, 'MX190201 2019-09-18')
    warning('%s: mouse not behaving much since 274.', sessionId);
    s.satTrialNum = 1 : 274;
    s.intanTrialNum = 1 : 274;
    s.hsvTrialNum = 1 : 274;
elseif strcmp(sessionId, 'MX210602 2021-06-16')
    warning('%s: SteamPix had errors in trial 120 and 121.', sessionId);
    s.satTrialNum = [1:119 122:263];
    s.intanTrialNum = [1:119 122:263];
    s.hsvTrialNum = [1:119 122:263];
end

end

