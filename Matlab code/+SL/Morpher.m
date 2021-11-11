classdef Morpher < handle
    
    properties(Constant)
        dtUnit = 1/6.5;
        rLim = 1.5;
    end
    
    properties
        tReal;
        tMorph;
        tAnchor;
        dtAvg;
        giObj;
    end
    
    methods
        function this = Morpher(tLicks, tAnchors)
            % Morpher construct an instance of this class
            
            % Handle user inputs
            if nargin == 0
                % Allow for constructing array
                return;
            end
            if ~iscell(tLicks)
                tLicks = {tLicks};
            end
            if nargin < 2
                tAnchors = cell(size(tLicks));
            end
            if ~iscell(tAnchors)
                tAnchors = num2cell(tAnchors, 2);
            end
            
            % Find unit ILI
            dtLicks = cellfun(@diff, tLicks, 'Uni', false);
            dtCat = cell2mat(dtLicks);
            dtMed = median(dtCat);
            
            for k = numel(tLicks) : -1 : 1
                % Cache values
                tr = tLicks{k}(:);
                dt = dtLicks{k}(:);
                ta = tAnchors{k}(:);
                
                if numel(tr) < 2
                    % No lick bout to morph
                    tm = tr;
                    gi = [];
                else
                    % Compute morphed times
                    dtm = dt;
                    dtm(dt < dtMed * SL.Morpher.rLim) = SL.Morpher.dtUnit;
                    tm = [0; cumsum(dtm)] + tr(1);
                    
                    % Make interpolant
                    tra = [tr; ta];
                    tma = [tm; ta];
                    [tra, ind] = unique(tra);
                    tma = tma(ind);
                    gi = griddedInterpolant(tra, tma, 'linear', 'linear');
                end
                
                % Save values
                this(k,1).tReal = tr;
                this(k,1).tMorph = tm;
                this(k,1).tAnchor = ta;
                this(k,1).dtAvg = dtMed;
                this(k,1).giObj = gi;
            end
        end
        
        function val = IsMorph(this)
            val = ~arrayfun(@(x) isempty(x.giObj), this);
        end
        
        function val = IsAnchored(this)
            val = arrayfun(@(x) ~isempty(x.tAnchor), this);
        end
        
        function s = Stats(this)
            % Compute fraction of streching in each ILI
            ism = this.IsMorph;
            dtr = cell2mat(arrayfun(@(x) diff(x.tReal), this(ism), 'Uni', false));
            dtm = cell2mat(arrayfun(@(x) diff(x.tMorph), this(ism), 'Uni', false));
            r = (dtm./dtr) - 1;
            s.realILI = dtr;
            s.morphILI = dtm;
            s.rILI = r;
            s.rMeanILI = mean(abs(r));
            s.rSdILI = std(r);
            s.rIqrILI = prctile(r, [25 75]);
            s.avgILI = cat(1, this.dtAvg);
        end
        
        function [t, v] = Morph(this, t, v)
            % Apply mapping to event times or time series
            
            assert(numel(this) == 1, 'This method can only be called by one object at a time');
            
            % Return inputs if no morphing is needed
            if ~this.IsMorph
                return;
            end
            
            % Map sample times
            if isnumeric(t)
                tOld = t;
                t = this.giObj(t);
            else
                t = t.Morph(this.giObj); % require a Morph interface that accepts griddedInterpolant object
                return;
            end
            
            % Resmaple after morphing with original sample times
            if nargin > 2
                dtype = class(v);
                v = interp1(t, double(v), tOld, 'linear', 'extrap');
                v = cast(v, dtype);
                t = tOld;
            end
        end
        
        function etTb = MorphEventTimes(this, etTb)
            % Apply mapping to an event time table
            
            assert(numel(this) == height(etTb), ...
                'There are %d Strecher objects but %d trials in the table', ...
                numel(this), height(etTb));
            
            for i = 1 : width(etTb)
                etCol = etTb.(i);
                for k = 1 : numel(this)
                    if isnumeric(etCol)
                        etCol(k) = this(k).Morph(etCol(k));
                    else
                        etCol{k} = this(k).Morph(etCol{k});
                    end
                end
                etTb.(i) = etCol;
            end
        end
        
        function tsTb = MorphTimeSeries(this, tsTb)
            % Apply mapping to an time series table
            
            assert(numel(this) == height(tsTb), ...
                'There are %d Strecher objects but %d trials in the table', ...
                numel(this), height(tsTb));
            
            for k = 1 : numel(this)
                for i = 2 : width(tsTb)
                    [~, tsTb.(i){k}] = this(k).Morph(tsTb.time{k}, tsTb.(i){k});
                end
            end
        end
    end
    
    methods(Static)
        function MorphSE(se, ops)
            % Apply mapping to all data in a SE object
            
            % Construct Morpher objects
            bt = se.GetTable('behavTime');
            switch ops.lickTimeType
                case 'mid'
                    tLicks = cellfun(@(x) x.MidTime, bt.lickObj, 'Uni', false);
                case 'shooting'
                    [~, ~, tLicks] = cellfun(@(x) x(x.IsTracked).ShootingLength, bt.lickObj, 'Uni', false);
                otherwise
                    error('''%s'' is not a valid option for ops.lickTimeType', ops.lickTimeType)
            end
            
            tRef = se.GetReferenceTime();
            tEnd = [diff(tRef); 600];
            tAnchors = [bt.cue tEnd];
            
            mObjs = SL.Morpher(tLicks, tAnchors);
            
            % Morph times in each table
            for i = 1 : numel(se.tableNames)
                if se.isEventValuesTable(i)
                    continue;
                end
                tb = se.GetTable(se.tableNames{i});
                if se.isEventTimesTable(i)
                    tb = mObjs.MorphEventTimes(tb);
                else
                    tb = mObjs.MorphTimeSeries(tb);
                end
                se.SetTable(se.tableNames{i}, tb);
            end
            
            % Add Morpher objects to an eventValues table
            se.SetColumn('behavValue', 'morphObj', mObjs);
        end
    end
end




