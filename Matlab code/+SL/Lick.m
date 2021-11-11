classdef Lick < MSessionExplorer.Event
    
    properties
        coor = NaN(1,4);
        length = NaN;
        velocity = NaN;
        angle = NaN;
        forceV = NaN;
        forceH = NaN;
        force = NaN;
        portPos = NaN;
        isDrive = false;
        isReward = false;
    end
    
    methods
        % Object Construction
        function obj = Lick(tchOn, tchOff, hsvTime, tonState)
            %LICK Construct an instance of this class
            
            % Default values for T
            s.tTouchOn = NaN;
            s.tTouchOff = NaN;
            s.tOut = NaN;
            s.tIn = NaN;
            s.tHSV = NaN;
            s.tADC = NaN;
            
            % Handle user inputs
            switch nargin
                case 0
                    % Allow for constructing Lick array
                    obj.T = s;
                    return;
                case 2
                    % When video data is not available
                    hsvTime = [];
                    tonState = [];
            end
            
            % Get windows of touch
            wTouch = [tchOn tchOff];
            wTouch(isnan(tchOn),:) = []; % remove placeholders
            
            % Convert time series of tongue state to windows
            iwOut = MMath.Logical2Bounds(tonState);
            wOut = hsvTime(iwOut);
            if iscolumn(wOut)
                wOut = wOut'; % keep it a row vector
            end
            
            % Merge multiple touches in single tongue-outs and vice versa
            if ~isempty(wOut) && ~isempty(wTouch)
                linkMat = SL.Lick.IsWinOverlap(wOut, wTouch);
                wOut = SL.Lick.FuseWin(wOut, linkMat, 'tongue-out');
                wTouch = SL.Lick.FuseWin(wTouch, linkMat', 'touch');
            end
            
            % Find touches with hsv
            linkMat = SL.Lick.IsWinOverlap(wOut, wTouch);
            wTouchVid = NaN(size(wOut));
            for i = 1 : size(wOut, 1)
                idx = find(linkMat(i,:), 1);
                if ~isempty(idx)
                    wTouchVid(i,:) = wTouch(idx,:);
                end
            end
            
            % Find touches without hsv and fill in other variables
            isTouchNoVid = ~any(linkMat, 1);
            wTouchNoVid = wTouch(isTouchNoVid,:);
            wOutNoVid = NaN(size(wTouchNoVid));
            
            % Constructing Lick array
            ww = [wTouchVid wOut; wTouchNoVid wOutNoVid];
            if isempty(ww)
                obj.T = s;
                return;
            end
            
            % Add values to object
            for i = size(ww,1) : -1 : 1
                s.tTouchOn = ww(i,1);
                s.tTouchOff = ww(i,2);
                s.tOut = ww(i,3);
                s.tIn = ww(i,4);
                
                if ~isnan(s.tTouchOn)
                    obj(i,1).t = s.tTouchOn;
                elseif ~isnan(s.tOut)
                    obj(i,1).t = (s.tOut + s.tIn) / 2;
                end
                
                obj(i,1).T = s;
            end
        end
        
        function obj = ResolvePositionInfo(obj, tPos, iPos, posDelay)
            % Add attributes regarding the sequence to objects in a single trial
            
            % Check if the trial has any licks
            if all(isnan(obj))
                return
            end
            
            if nargin < 4
                posDelay = 0.08; % default refractory period of driving
            end
            ttPos = [-Inf; tPos + posDelay]; % assume single trial and use -Inf
            iiPos = [iPos(1) + diff(iPos([2 1])); iPos]; % assume normal transition for the first drive
            
            for k = 1 : numel(obj)
                % Check lick
                tLick = obj(k).t;
                if isnan(tLick) % not a valid lick
                    continue;
                end
                
                % Determine port position during lick
                dt = tLick - ttPos;
                idx = find(dt >= 0, 1, 'last');
                obj(k).portPos = iiPos(idx);
                
                % Check if it's a driving lick
                if obj(k).IsTouch
                    dt = tLick - tPos;
                    obj(k).isDrive = any(dt <= 0 & dt >= -0.005); % allows for 5ms of delayed report (may not be necessary)
                end
                
                % Check if it's the lick that triggers water reward
                if k > 1 && obj(k-1).isDrive && obj(k).IsTouch && ~obj(k).isDrive
                    obj(k).isReward = true;
                end
            end
        end
        
        function obj = AddHSV(obj, ts, C, L, A)
            for i = 1 : numel(obj)
                s = obj(i).T;
                if isnan(s.tOut)
                    continue;
                end
                mask = ts >= s.tOut & ts <= s.tIn;
                if any(mask)
                    s.tHSV = ts(mask);
                    obj(i).T = s;
                    obj(i).coor = C(mask,:);
                    obj(i).length = L(mask);
                    obj(i).velocity = gradient(L(mask), 1/SL.Param.frPerSec);
                    obj(i).angle = A(mask);
                end
            end
        end
        
        function obj = AddADC(obj, ts, FV, FH)
            for i = 1 : numel(obj)
                s = obj(i).T;
                if isnan(s.tTouchOn)
                    continue;
                end
                mask = ts >= s.tTouchOn & ts <= s.tTouchOff;
                if any(mask)
                    obj(i).T.tADC = ts(mask);
                    obj(i).forceV = FV(mask);
                    obj(i).forceH = FH(mask);
                    obj(i).force = sqrt(obj(i).forceV.^2 + obj(i).forceH.^2);
                end
            end
        end
        
        % Object Modifiers
        function obj = Morph(obj, gi)
            for i = 1 : numel(obj)
                obj(i).t = gi(obj(i).t);
                obj(i).T = structfun(@(x) gi(x), obj(i).T, 'Uni', false);
            end
        end
        
        function obj = InvertDirection(obj)
            for i = 1 : numel(obj)
                obj(i).angle = -obj(i).angle;
                obj(i).forceH = -obj(i).forceH;
            end
        end
        
        function obj = StandardizeAngle(obj, offset, scale)
            for i = 1 : numel(obj)
                obj(i).angle = (obj(i).angle - offset) * scale;
            end
        end
        
        function objs = Resample(objs, nPtInterp)
            
            for i = 1 : numel(objs)
                obj = objs(i);
                
                % Find lick window
                tHSV = obj.T.tHSV;
                tADC = obj.T.tADC;
                tWin = tHSV([1 end]);
                ti = linspace(tWin(1), tWin(2), nPtInterp)';
                
                % Interpolate HSV data
                if numel(tHSV) > 1
                    obj.length = interp1(tHSV, obj.length, ti, 'linear');
                    obj.velocity = interp1(tHSV, obj.velocity, ti, 'linear');
                    obj.angle = interp1(tHSV, obj.angle, ti, 'linear');
                else
                    obj.length = NaN(size(ti));
                    obj.velocity = NaN(size(ti));
                    obj.angle = NaN(size(ti));
                end
                
                % Interpolate ADC data
                if numel(tADC) > 1
                    obj.forceV = interp1(tADC, obj.forceV, ti, 'linear', 0);
                    obj.forceH = interp1(tADC, obj.forceH, ti, 'linear', 0);
                else
                    obj.forceV = NaN(size(ti));
                    obj.forceH = NaN(size(ti));
                end
                obj.force = sqrt(obj.forceH.^2 + obj.forceV.^2);
                
                % Normalize time
                obj.T.ti = ti;
                if ti(1) == ti(end)
                    gi = griddedInterpolant(ti(1)+[-1 1]', [-1 1]');
                else
                    gi = griddedInterpolant(ti([1 end]), [-1 1]');
                end
                obj = obj.Morph(gi);
                
                objs(i) = obj;
            end
        end
        
        % Getters
        function val = IsValid(obj)
            val = ~isnan(obj);
        end
        
        function val = IsTouch(obj)
            val = zeros(size(obj));
            for i = 1 : numel(obj)
                val(i) = obj(i).T.tTouchOn;
            end
            val = ~isnan(val);
        end
        
        function val = IsTracked(obj)
            val = zeros(size(obj));
            for i = 1 : numel(obj)
                val(i) = obj(i).T.tOut;
            end
            val = ~isnan(val);
        end
        
        function [t, tLick, tTouch] = MidTime(obj)
            % Find the mid time of tongue protrusion (tLick) and touch (tTouch)
            % t uses tLick, or tTouch when tLick is NaN
            tLick = NaN(size(obj));
            tTouch = NaN(size(obj));
            for k = 1 : numel(obj)
                tLick(k) = (obj(k).T.tOut + obj(k).T.tIn) / 2;
                tTouch(k) = (obj(k).T.tTouchOn + obj(k).T.tTouchOff) / 2;
            end
            t = tLick;
            t(isnan(tLick)) = tTouch(isnan(tLick));
        end
        
        function [maxLen, iMax, tMax] = MaxLength(obj)
            maxLen = NaN(size(obj));
            iMax = NaN(size(obj));
            tMax = NaN(size(obj));
            isTracked = obj.IsTracked;
            for k = 1 : numel(obj)
                if isTracked(k)
                    [maxLen(k), iMax(k)] = nanmax(obj(k).length);
                    tMax(k) = obj(k).T.tHSV(iMax(k));
                end
            end
        end
        
        function [A, iMax, tMax] = AngleAtMaxLength(obj)
            [~, iMax, tMax] = obj.MaxLength();
            A = NaN(size(obj));
            isTracked = obj.IsTracked;
            for k = 1 : numel(obj)
                if isTracked(k)
                    A(k) = obj(k).angle(iMax(k));
                end
            end
        end
        
        function [L, iL, tL] = ShootingLength(obj)
            L = NaN(size(obj));
            iL = NaN(size(obj));
            tL = NaN(size(obj));
            isTracked = obj.IsTracked;
            for k = 1 : numel(obj)
                if isTracked(k)
                    len = obj(k).length;
                    iL(k) = find(len./nanmax(len) >= SL.Param.fracLen4Shoot, 1);
                    L(k) = len(iL(k));
                    tL(k) = obj(k).T.tHSV(iL(k));
                end
            end
        end
        
        function [A, iA, tA] = ShootingAngle(obj)
            [~, iA, tA] = obj.ShootingLength();
            A = NaN(size(obj));
            isTracked = obj.IsTracked;
            for k = 1 : numel(obj)
                if isTracked(k)
                    A(k) = obj(k).angle(iA(k));
                end
            end
        end
        
        function ind = TouchVidInd(obj)
            ind = cell(size(obj));
            isTrackedTouch = obj.IsTouch & obj.IsTracked;
            for k = 1 : numel(obj)
                if isTrackedTouch(k)
                    s = obj(k).T;
                    ind{k} = s.tHSV >= s.tTouchOn & s.tHSV <= s.tTouchOff;
                end
            end
        end
        
        function [A, iTouch, tTouch] = AngleAtTouch(obj)
            A = NaN(size(obj));
            iTouch = NaN(size(obj));
            tTouch = NaN(size(obj));
            maskTouch = TouchVidInd(obj);
            for k = 1 : numel(obj)
                idx = find(maskTouch{k}, 1);
                if ~isempty(idx)
                    iTouch(k) = idx;
                    A(k) = obj(k).angle(idx);
                    tTouch(k) = obj(k).T.tHSV(idx);
                end
            end
        end
        
        function [L, iTouch, tTouch] = LengthAtTouch(obj)
            L = NaN(size(obj));
            iTouch = NaN(size(obj));
            tTouch = NaN(size(obj));
            maskTouch = TouchVidInd(obj);
            for k = 1 : numel(obj)
                idx = find(maskTouch{k}, 1);
                if ~isempty(idx)
                    iTouch(k) = idx;
                    L(k) = obj(k).length(idx);
                    tTouch(k) = obj(k).T.tHSV(idx);
                end
            end
        end
        
        function [maxF, iMax, tMax] = MaxForce(obj)
            maxF = NaN(size(obj));
            iMax = NaN(size(obj));
            tMax = NaN(size(obj));
            isTouch = obj.IsTouch;
            for k = 1 : numel(obj)
                if isTouch(k)
                    F = obj(k).force;
                    [maxF(k), iMax(k)] = nanmax(F);
                    tMax(k) = obj(k).T.tADC(iMax(k));
                end
            end
        end
    end
    
    methods(Static)
        function C = IsWinOverlap(a, b)
            C = false(size(a,1), size(b,1));
            for n = 1 : size(a,1)
                C(n,:) = ~(b(:,2) < a(n,1) | b(:,1) > a(n,2));
            end
        end
        
        function w = FuseWin(w, C, winType)
            colSum = sum(C, 1);
            for n = 1 : size(C,2)
                if colSum(n) > 1
                    ii = find(C(:,n));
                    w(ii(1),2) = w(ii(end),2);
                    w(ii(2:end),:) = NaN;
                    if nargin == 3
                        fprintf('%d %s windows fused to one\n', colSum(n), winType);
                    end
                end
            end
            w(isnan(w(:,1)),:) = [];
        end
    end
end

