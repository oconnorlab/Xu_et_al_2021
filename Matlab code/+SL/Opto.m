classdef Opto
    
    methods(Static)
        function aaTb = LoadAnimalAreaTable(cachePaths)
            % Load extracted aaTb
            
            aaCell = cell(size(cachePaths));
            for i = 1 : numel(cachePaths)
                load(cachePaths{i});
                aaCell{i} = aaTb;
            end
            aaTb = vertcat(aaCell{:});
        end
        
        function A = CombineAnimalAreaTableRows(aa)
            % Combine data across animals for each area. Also label trials with animal ID for hier. bootstrap.
            %   aa is a table or a table-like cell array where rows are animals and cols are areas
            %   A is a single-row cell array where data across animals is merged
            
            if istable(aa)
                aa = aa{:,:};
            end
            
            A = cell(1, size(aa,2));
            for i = 1 : numel(A)
                % Concatenate condition tables
                catTb = vertcat(aa{:,i});
                
                % Merge same conditions
                [~, condTb] = findgroups(catTb(:,'opto'));
                condTb = SL.SE.CombineConditions(condTb, catTb);
                
                for j = 1 : height(condTb)
                    % Reduce redundancy
                    condTb.animalId{j} = unique(condTb.animalId{j}, 'stable');
                    condTb.sessionId{j} = unique(condTb.sessionId{j}, 'stable');
                    
                    % Label trials with animal ID
                    numTrials = condTb.numTrial{j};
                    labels = cell(size(numTrials));
                    for k = 1 : numel(numTrials)
                        labels{k} = repmat(k, [numTrials(k) 1]);
                    end
                    condTb.animalLabel{j} = cell2mat(labels);
                end
                
                % Put non-opto condition to the end (for backward compatibility)
                condTb = condTb([2 3 4 1],:);
                
                A{i} = condTb;
            end
        end
        
        function s = QuantifyPerf(lkTb, s)
            % A pipeline for computing time series (or scalar) of lick/touch rate, theta, L, etc.
            
            % Add metadata
            if iscell(lkTb.xlsInfo)
                s.info = lkTb.xlsInfo{1}(1);
            else
                s.info = lkTb.xlsInfo(1);
            end
            
            % Prepare inputs
            trigTb = lkTb(:,{'tInit','tMid','tCons'});
            lickObj = lkTb.lickObj;
            if ismember('animalLabel', lkTb.Properties.VariableNames)
                hbInd = lkTb.animalLabel;
            else
                hbInd = cell(size(lickObj));
            end
            
            % Compute mean lick quantities
            quantList = {'len', 'ang', 'angSD', 'angAbs', 'dAng'};
            for i = 1 : numel(quantList)
                q = quantList{i};
                if ~isfield(s, q)
                    continue;
                end
                [s.(q).opto, s.(q).ctrl, s.(q).optoBoot, s.(q).ctrlBoot] = ...
                    SL.Opto.ComputeQuant(trigTb, lickObj, s.(q).tEdges, q, s.(q).nboot, hbInd);
            end
            
            % Compute lick and touch rates
            if isfield(s, 'rLick')
                [s.rLick.opto, s.rLick.ctrl, s.rLick.optoBoot, s.rLick.ctrlBoot] = ...
                    SL.Opto.ComputeRate(trigTb, lickObj, s.rLick.tEdges, s.rLick.nboot, hbInd);
            end
            if isfield(s, 'rTouch')
                for j = numel(lickObj) : -1 : 1
                    touchObj{j,1} = cellfun(@(x) x(x.IsTouch), lickObj{j}, 'Uni', false);
                end
                [s.rTouch.opto, s.rTouch.ctrl, s.rTouch.optoBoot, s.rTouch.ctrlBoot] = ...
                    SL.Opto.ComputeRate(trigTb, touchObj, s.rTouch.tEdges, s.rTouch.nboot, hbInd);
            end
        end
        
        function [opto, ctrl, optoBoot, ctrlBoot] = ComputeQuant(trigTb, lickObj, tEdges, quantName, nboot, hbInd)
            % Quantify a given discretized lick variable (e.g. Theta_shoot, L_max, etc.) in each time bin
            % Inputs
            %   tEdges      Edges of time bins in time-by-period array
            %   nboot       Number of bootstrap resampling. If zero, no bootstrap
            %   hbInd       Indices for hierarchical bootstrap CI. Each trial has an index
            % Outputs 
            %   opto, ctrl              time-by-(mean,sd,#obs)-by-period array
            %   optoBoot, ctrlBoot      time-by-boot-by-period array of means
            
            % For opto
            for i = width(trigTb) : -1 : 1
                licks = lickObj{i};
                t0 = trigTb{i,i}{1};
                licks = cellfun(@(x,y) x-y, licks, num2cell(t0), 'Uni', false);
                [opto(:,:,i), optoBoot(:,:,i)] = SL.Opto.QuantMeanCI(licks, tEdges(:,i), quantName, nboot, hbInd{i});
            end
            
            % For non-opto
            for i = width(trigTb) : -1 : 1
                licks = lickObj{4};
                t0 = trigTb{4,i}{1};
                licks = cellfun(@(x,y) x-y, licks, num2cell(t0), 'Uni', false);
                [ctrl(:,:,i), ctrlBoot(:,:,i)] = SL.Opto.QuantMeanCI(licks, tEdges(:,i), quantName, nboot, hbInd{4});
            end
        end
        
        function [stats, bootstats] = QuantMeanCI(L, tEdges, qName, nboot, hbInd)
            % Inputs
            %   L           n-by-1 cell array of lickObjs where n is the number of trials
            %   t0          n-by-1 numeric array of trigger times
            % Outputs
            %   stats       t-by-s matrix where t is the number of time bins, s is for mean, SD, #samples
            %   Q           t-by-1 cell array containing samples in each time bin
            %   If no sample is found, stats is a zero matrix and qBin is an empty t-by-1 cell array
            
            % Expand trial animal IDs to every licks
            if isempty(hbInd)
                hbInd = ones(size(L));
            end
            nL = cellfun(@numel, L);
            i = repelem(hbInd, nL);
            
            % Get the inquired quantities and corresponding timestamps
            L = cat(1, L{:});
            if ismember(qName, {'ang', 'angSD', 'angAbs'})
                [q, ~, t] = ShootingAngle(L);
                if strcmp(qName, 'angAbs')
                    q = abs(q);
                end
            elseif strcmp(qName, 'len')
                [q, ~, t] = MaxLength(L);
            else
                error('%s is not a supported quantity to compute', qName);
            end
            
            % Bin samples
            [~, ~, subs] = histcounts(t, tEdges, 'Normalization', 'probability');
            isOutside = subs == 0;
            subs(isOutside) = [];
            q(isOutside) = [];
            i(isOutside) = [];
            nBins = numel(tEdges) - 1;
            Q = accumarray(subs, q, [nBins 1], @(x) {x}, {});
            I = accumarray(subs, i, [nBins 1], @(x) {x}, {});
            
            % Compute stats
            if isempty(q)
                stats = NaN(nBins, 5);
                bootstats = zeros(nBins, 0);
            else
                [m, sd, se] = cellfun(@MMath.MeanStats, Q);
                n = accumarray(subs, 1, [nBins 1]);
                
                if strcmp(qName, 'angSD')
                    m = sd;
                    sd(:) = NaN;
                    se(:) = NaN;
                    bootfun = @nanstd;
                else
                    bootfun = @nanmean;
                end
                
                if nboot
                    [~, bootstats] = cellfun( ...
                        @(x,y) MMath.BootCI(nboot, {bootfun, x}, 'Groups', y), ...
                        Q, I, 'Uni', false);
                    bootstats = cat(2, bootstats{:})';
                else
                    bootstats = zeros(nBins, 0);
                end
                
                stats = cat(2, m, sd, n);
            end
        end
        
        function [opto, ctrl, optoBoot, ctrlBoot] = ComputeRate(trigTb, lickObj, tEdges, nboot, hbInd)
            % Compute lick or touch rate for each time bin
            % Inputs
            %   nboot       Number of bootstrap resampling. If zero, no bootstrap.
            %   hbInd       Indices for hierarchical bootstrap CI. Each trial has an index.
            % Each output is a t-by-s-by-p matrix
            %   t is the number of time bins
            %   s is three statistics: mean, SD, SEM
            %   p is three manipulation periods
            
            % For opto
            opto = zeros(size(tEdges,1)-1, 3, width(trigTb));
            for i = width(trigTb) : -1 : 1
                licks = lickObj{i};
                t0 = trigTb{i,i}{1};
                tLicks = cellfun(@(x,y) double(x)-y, licks, num2cell(t0), 'Uni', false);
                [opto(:,:,i), optoBoot(:,:,i)] = SL.Opto.RateMeanCI(tLicks, tEdges(:,i), nboot, hbInd{i});
            end
            
            % For non-opto
            ctrl = zeros(size(tEdges,1)-1, 3, width(trigTb));
            for i = width(trigTb) : -1 : 1
                licks = lickObj{4};
                t0 = trigTb{4,i}{1};
                tLicks = cellfun(@(x,y) double(x)-y, licks, num2cell(t0), 'Uni', false);
                [ctrl(:,:,i), ctrlBoot(:,:,i)] = SL.Opto.RateMeanCI(tLicks, tEdges(:,i), nboot, hbInd{4});
            end
        end
        
        function [stats, bootstats] = RateMeanCI(xx, edges, nboot, hbInd)
            % Inputs
            %   xx          n-by-1 cell array of lick times where n is the number of trials
            % Outputs
            %   stats       t-by-s matrix where t is the number of time bins, s is for mean, SD, SEM
            %   bootstats   t-by-nboot matrix
            
            % Compute histogram for each trial
            n = zeros(numel(xx), numel(edges)-1);
            for j = 1 : size(n,1)
                n(j,:) = histcounts(xx{j}, edges, 'Normalization', 'countdensity');
            end
            
            % Compute mean stats with all data
            [m, sd, se] = MMath.MeanStats(n);
            stats = [m; sd; se]';
            
            % Bootstrap means
            if nboot
                [~, bootstats] = MMath.BootCI(nboot, {@(x) mean(x)', n}, ...
                    'Groups', hbInd, 'Options', statset('UseParallel', true));
                bootstats = bootstats';
            else
                bootstats = zeros(numel(m), 0);
            end
        end
        
        function s = MixRateStats(s)
            % Recombine data in rLick and rTouch that are of the same periods
            mixNames = {'rInit', 'rMid', 'rCons'};
            arrNames = {'opto', 'ctrl', 'optoBoot', 'ctrlBoot'};
            for i = 1 : numel(mixNames)
                mn = mixNames{i};
                s.(mn) = s.rLick;
                for j = 1 : numel(arrNames)
                    an = arrNames{j};
                    s.(mn).(an) = cat(3, s.rLick.(an)(:,:,i), s.rTouch.(an)(:,:,i));
                end
            end
        end
        
        function q = AppendCI(q, alpha)
            % Compute single mean values and CIs from bootstrap mean timeseries
            %
            % Required fields in q
            %   ctrl/opto           time-by-(mean,sd,#obs)-by-period array
            %
            % Fields being changed or added to q
            %   ctrl/opto           time-by-(mean,sd,#obs,ci1,ci2)-by-period array
            
            % Compute and append timeseries CI
            prct = 100 * [alpha/2, 1-alpha/2]';
            q.ctrl(:,4:5,:) = prctile(q.ctrlBoot, prct, 2);
            q.opto(:,4:5,:) = prctile(q.optoBoot, prct, 2);
        end
        
        function q = DeriveScalarStats(q, alpha)
            % Compute single mean values and CIs from bootstrap mean timeseries
            %
            % Required fields in q
            %   ctrl/opto           time-by-(mean,sd,#obs)-by-period array
            %   ctrlBoot/optoBoot   time-by-boot-by-period array
            %
            % Fields being changed or added to q
            %   scalar3             (ctrl,opto)-by-(mean,ci1,ci2)-by-period, 2x3x3 array
            %   scalar              (ctrl,opto)-by-(mean,ci1,ci2), 2x3 array
            %   pVal3               1-by-period (1x3)
            %   pVal                scalar
            
            prct = 100 * [alpha/2, 1-alpha/2]';
            
            % Average across time (time-by-boot-by-period to 1-by-boot-by-period)
            cm = nanmean(q.ctrl(:,1,:));
            om = nanmean(q.opto(:,1,:));
            cb = nanmean(q.ctrlBoot, 1);
            ob = nanmean(q.optoBoot, 1);
            
            % Compute mean±CI and run test
            q.scalar3 = [ ...
                cm, prctile(cb, prct, 2); ...
                om, prctile(ob, prct, 2); ...
                ];
            for i = size(q.ctrl,3) : -1 : 1
                [~, q.pVal3(i)] = MMath.BootTest2(cb(:,:,i), ob(:,:,i));
            end
            
            % Further average across periods (1-by-nboot-by-p to 1-by-nboot)
            cm = nanmean(cm, 3);
            om = nanmean(om, 3);
            cb = nanmean(cb, 3);
            ob = nanmean(ob, 3);
            
            % Compute mean±CI and run test
            q.scalar = [ ...
                cm, prctile(cb, prct, 2); ...
                om, prctile(ob, prct, 2); ...
                ];
            [~, q.pVal] = MMath.BootTest2(cb, ob);
        end
        
        function s = ReshapeSummaryStats(diffCell)
            s = diffCell{1};
            fieldNames = fieldnames(s);
            for i = 1 : numel(fieldNames)
                fn = fieldNames{i};
                val = cellfun(@(x) x.(fn), diffCell, 'Uni', false);
                val = cell2mat(val);
                val = reshape(val, size(diffCell,1), 3, size(diffCell,2));
                s.(fn) = val;
            end
        end
        
        function areaCell = IndexLicks(areaCell, defaultName)
            
            for i = 1 : numel(areaCell) % through areas
                for j = 1 : height(areaCell{i}) % through conditions
                    for k = 1 : numel(areaCell{i}.lickObj{j}) % through trials
                        % Cache variables
                        licks = areaCell{i}.lickObj{j}{k};
                        tLicks = double(licks);
                        tMid = areaCell{i}.tMid{j}(k);
                        tCons = areaCell{i}.tCons{j}(k);
                        
                        % Index licks from Init
                        ids = (1 : numel(licks))';
                        ids(tLicks > 2) = NaN;
                        licks = licks.SetVfield('initId', ids);
                        
                        % Index licks from Mid
                        [~, iTrig] = min(abs(tLicks - tMid));
                        ids = (1 : numel(licks))';
                        ids = ids - iTrig;
                        ids(tLicks - tMid > 2) = NaN;
                        licks = licks.SetVfield('midId', ids);
                        
                        % Index licks from Cons
                        [~, iTrig] = min(abs(tLicks - tCons));
                        iRw = find([licks.isReward], 1);
                        ids = (1 : numel(licks))';
                        ids = ids - iTrig;
                        ids(1:iRw) = NaN;
                        ids(tLicks - tCons > 2) = NaN;
                        licks = licks.SetVfield('consId', ids);
                        
                        % Add default indices
                        if exist('defaultName', 'var')
                            ids = licks.GetVfield(defaultName);
                            licks = licks.SetVfield('lickId', ids);
                        end
                        
                        areaCell{i}.lickObj{j}{k} = licks;
                    end
                end
            end
        end
        
        function [d, f, p, w] = AnalyzeWaveform(t, v, th)
            % Find duration, frequency, peak height and half-peak width of a periodic or 
            % non-periodic waveform
            % 
            %   [dur, f, p, w] = AnalyzeWaveform(t, s)
            %   [dur, f, p, w] = AnalyzeWaveform(t, s, th)
            
            % Handle user inputs
            if nargin < 3
                th = 0;
            end
            
            % Defaults
            d = 0;
            f = 0;
            p = 0;
            w = 0;
            
            if any(v > th)
                v = double(v);
                [p, tPk, w] = findpeaks(v, t, 'MinPeakHeight', th);
                N = numel(tPk);
                if N == 1
                    % Single pulse
                    iEnd = find(v > th, 1, 'last');
                    d = t(iEnd) - tPk;
                else
                    % Multiple pulses
                    T = mean(diff(tPk));
                    d = T * N;
                    f = 1 / T;
                    p = mean(p);
                    w = mean(w);
                end
            end
        end
        
        function pd = ComputePowerDensity(P)
            % Specs of FT400UMT
            Df = 0.4; % fiber diameter, mm
            NA = 0.39;
            
            % Assumed values
            n = 1; % index of refraction in air
            d = 1.5; % distance to brain, mm
            r = 0.5; % transmission efficiency
            
            % Compute density
            ang = asind(NA / n);
            Db = Df + d * tand(ang);
            A = pi*(Db/2)^2;
            pd = P*r/A;
        end
        
        function [eff, bootstat] = ComputeEfficiencyCurves(cfTb, unitType)
            % Compute opto efficiency curves
            
            nPower = height(cfTb.seTb{1});
            eff = zeros(nPower, 5, height(cfTb)); % mean, sem, ci-, ci+, #samples
            bootstat = cell(height(cfTb), 1);
            
            for i = 1 : height(cfTb)
                % Select units
                rm = cfTb.rMean{i};
                gi = cfTb.gInd{i};
                tPk2Pk = cfTb.tPk2Pk{i};
                tCut = SL.Param.fsPyrCutoff;
                
                isActive = rm(:,1) > 2;             % baseline spike rate too low
                isExcited = rm(:,end) > rm(:,1)*2;  % spike rate increased by more than two-fold
                isPyr = tPk2Pk > tCut(2);           % Putative pyramidal neurons
                isFS = tPk2Pk < tCut(1);            % Putative FS neurons
                
                if strcmpi(unitType, 'pyr')
                    isSelect = isPyr & isActive & ~isExcited;
                elseif strcmpi(unitType, 'FS')
                    isSelect = isFS;
                end
                
                rm = rm(isSelect,:);
                gi = gi(isSelect,:);
                N = sum(isSelect);
                
                % Normalize to baseline spike rate
                rm = rm ./ max(rm(:,1),1);
                
                % Compute mean stats
                [m, ~, sem] = MMath.MeanStats(rm, 1);
                
                % Compute bootstrap CI
                [ci, bootstat{i}] = MMath.BootCI(2e3, {@(x) mean(x)', rm}, 'Groups', gi, ...
                    'Alpha', 0.05, 'Options', statset('UseParallel', true));
                
                eff(:,1,i) = m;
                eff(:,2,i) = sem;
                eff(:,3:4,i) = ci';
                eff(:,5,i) = N;
            end
        end
        
        function PlotEfficiencyDists(cfTb, unitType)
            % 
            
            for i = 1 : height(cfTb)
                % Select units
                r = cfTb.rMean{i};
                gi = cfTb.gInd{i};
                tPk2Pk = cfTb.tPk2Pk{i};
                tCut = SL.Param.fsPyrCutoff;
                
                isActive = r(:,1) > 2;             % enough baseline spike rate
                isExcited = r(:,end) > r(:,1)*2;  % spike rate increased by more than two-fold
                isPyr = tPk2Pk > tCut(2);           % putative pyramidal neurons
                isFS = tPk2Pk < tCut(1);            % putative FS neurons
                
                if strcmpi(unitType, 'pyr')
                    isSelect = isPyr & isActive & ~isExcited;
                elseif strcmpi(unitType, 'FS')
                    isSelect = isFS;
                end
                
                % Normalize to baseline spike rate
                r = r ./ max(r(:,1),1);
                
                % 
                b = 0:0.1:2;
                nPower = size(r,2);
                mice = unique(gi(:,1), 'stable');
                sess = unique(gi(:,2), 'stable');
                nMice = numel(mice);
                nSess = numel(sess);
                cc = lines(nMice);
                
                ax = subplot(3,1,i); cla
                disp(i);
                for j = 1 : nSess
                    hh = zeros(numel(b)-1, nPower);
                    isSess = gi(:,2)==sess(j);
                    mouse = gi(find(isSess,1),1);
                    for k = 1 : nPower
                        hh(:,k) = histcounts(r(isSelect & isSess,k), b, 'Normalization', 'probability');
                    end
                    pos = (1:nPower) + (j-nSess/2)*0.12;
                    MPlot.Violin(pos, repmat(b',1,size(hh,2)), hh/3, 'Color', cc(mouse,:));
                    plot([1.5 nPower+.5], [1 1], '--', 'Color', [0 0 0 .2]);
                    disp(sum(isSess & isSelect)+"/"+sum(isSess));
                end
                ax.XTick = 1:nPower;
                ax.XTickLabel = cfTb.seTb{i}.optoMod1*8 + " mW";
                xlim([1.5 nPower+.5]);
                ylim([0 2]);
                ylabel('Relative r');
            end
        end
        
        function [sInd, lickObj] = ExtractInitData(se)
            
            optoId = se.GetColumn('behavValue', 'opto');
            seqId = se.GetColumn('behavValue', 'seqId');
            lickObj = se.GetColumn('behavTime', 'lickObj');
            
            % Trial type indices
            indNone = find(isnan(optoId));
            indOpto = find(~isnan(optoId));
            indInit = find(optoId == 0);
            indMid = find(optoId == 1);
            indCons = find(optoId == 2);
            
            % Derived indices
            indFoll = indNone(ismember(indNone-1, indOpto));
            
            indFree = cell(1,6);
            indFree{1} = indNone;
            for i = 1 : numel(indFree)-1
                indFree{i+1} = indFree{i}(~ismember(indFree{i}-i, indOpto));
            end
            indFree(1) = [];
            
            for i = 1 : numel(lickObj)
                lk = lickObj{i};
                
                % Label licks from trial start
                lk = lk.SetVfield('startId', (1:numel(lk))');
                
                % Label licks from 2s offset (no lick in 2s)
                lb = NaN(size(lk));
                i2s = find(lk > 2, 1);
                if ~isempty(i2s) && i2s == 1
                    lb(i2s:end) = i2s : numel(lk);
                end
                lk = lk.SetVfield('postId', lb);
                
%                 % First few licks are enough
%                 lk = lk(1:15);
                
                % Invert direction
                if lk(1).portPos == 0
                    lk = lk.InvertDirection;
                end
                
                lickObj{i} = lk;
            end
            
            % Pack variables
            sInd.none = indNone;
            sInd.opto = indOpto;
            sInd.init = indInit;
            sInd.mid = indMid;
            sInd.cons = indCons;
            sInd.follow = indFoll;
            sInd.free = indFree;
        end
        
        
        % not in use
        function s = AveragePerf(ss)
            % Average multiple outputs of ComputeTraces (e.g. across mice)
            
            if iscell(ss)
                ss = [ss{:}];
            end
            s = ss(1);
            
            vars = fieldnames(s);
            vars(strcmp(vars,'info')) = [];
            conds = {'opto', 'ctrl'};
            
            for i = 1 : numel(vars)
                vn = vars{i};
                for j = 1 : numel(conds)
                    cn = conds{j};
                    sp = arrayfun(@(x) x.(vn).(cn), ss, 'Uni', false);
                    sp = cat(4, sp{:});
                    [m, sd] = MMath.MeanStats(sp, 4);
                    m(:,2:end,:) = NaN; % clear data
                    m(:,2,:) = sd(:,1,:); % add SD
                    m(:,3,:) = sum(~isnan(sp(:,1,:,:)), 4); % add # of samples
                    s.(vn).(cn) = m;
                end
            end
        end
        
        function [opto, ctrl] = ComputeQuant_Old(trigTb, lickObj, tEdges, quantName, aCI, hbInd)
            % Quantify discretized lick variables (e.g. Theta_shoot, L_max, etc.) for each time bin
            % Inputs
            %   tEdges  Bin edges. If t-by-3, applies to three periods individually. If t-by-1, applies
            %           to combined data from three periods.
            %   aCI     Alpha of bootstrap CI (e.g. aCI = 0.05)
            %   hbInd   Indices for hierarchical bootstrap CI. Each trial has an index.
            % Each output is a t-by-s-by-p matrix
            %   t is the number of time bins
            %   s is three statistics: mean, SD, # of samples, lower CI, upper CI
            %   p is three manipulation periods
            
            if ~exist('aCI', 'var')
                aCI = 0;
            end
            if ~exist('hbInd', 'var')
                hbInd = cell(size(lickObj));
            end
            
            % For opto
            alignedLicks = cell(width(trigTb), 1);
            for i = width(trigTb) : -1 : 1
                licks = lickObj{i};
                t0 = trigTb{i,i}{1};
                licks = cellfun(@(x,y) x-y, licks, num2cell(t0), 'Uni', false);
                alignedLicks{i} = licks;
                if size(tEdges,2) == 3
                    opto(:,:,i) = SL.Opto.QuantMeanCI(licks, tEdges(:,i), quantName, aCI, hbInd{i});
                end
            end
            if size(tEdges,2) == 1
                licks = cat(1, alignedLicks{:});
                hbIndCat = cat(1, hbInd{1:3});
                opto = SL.Opto.QuantMeanCI(licks, tEdges, quantName, aCI, hbIndCat);
            end
            
            % For non-opto
            alignedLicks = cell(width(trigTb), 1);
            for i = width(trigTb) : -1 : 1
                licks = lickObj{4};
                t0 = trigTb{4,i}{1};
                licks = cellfun(@(x,y) x-y, licks, num2cell(t0), 'Uni', false);
                alignedLicks{i} = licks;
                if size(tEdges,2) == 3
                    ctrl(:,:,i) = SL.Opto.QuantMeanCI(licks, tEdges(:,i), quantName, aCI, hbInd{4});
                end
            end
            if size(tEdges,2) == 1
                licks = cat(1, alignedLicks{:});
                hbIndCat = cat(1, hbInd{[4,4,4]});
                ctrl = SL.Opto.QuantMeanCI(licks, tEdges, quantName, aCI, hbIndCat);
            end
        end
        
        function [stats, Q] = QuantMeanCI_Old(L, tEdges, qName, aCI, hbInd)
            % Inputs
            %   L           n-by-1 cell array of lickObjs where n is the number of trials
            %   t0          n-by-1 numeric array of trigger times
            % Outputs
            %   stats       t-by-5 matrix where t is the number of time bins
            %   Q           t-by-1 cell array containing samples in each time bin
            %   If no sample is found, stats is a zero matrix and qBin is an empty t-by-1 cell array
            
            % Expand trial animal IDs to every licks
            if isempty(hbInd)
                hbInd = ones(size(L));
            end
            nL = cellfun(@numel, L);
            i = repelem(hbInd, nL);
            
            % Get the inquired quantities and corresponding timestamps
            if ismember(qName, {'ang', 'angsd', 'aang'})
                L = cat(1, L{:});
                [q, ~, t] = ShootingAngle(L);
                if strcmp(qName, 'aang')
                    q = abs(q);
                end
            elseif strcmp(qName, 'len')
                L = cat(1, L{:});
                [q, ~, t] = MaxLength(L);
            else
                error('%s is not a supported quantity to compute', qName);
            end
%             elseif strcmp(qName, 'dAng')
%                 for k = numel(L) : -1 : 1
%                     [qk, ~, tk] = ShootingAngle(L{k});
%                     if numel(qk) > 1
%                         q{k} = diff(qk);
%                         t{k} = tk(1:end-1) + diff(tk);
%                     end
%                 end
%                 q = cat(1, q{:});
%                 t = cat(1, t{:});
            
            % Bin samples
            [~, ~, subs] = histcounts(t, tEdges, 'Normalization', 'probability');
            isOutside = subs == 0;
            subs(isOutside) = [];
            q(isOutside) = [];
            i(isOutside) = [];
            nBins = numel(tEdges) - 1;
            Q = accumarray(subs, q, [nBins 1], @(x) {x}, {});
            I = accumarray(subs, i, [nBins 1], @(x) {x}, {});
            
            % Compute stats
            if isempty(q)
                stats = NaN(nBins, 5);
                Q = cell(nBins, 1);
                return
            end
            [m, sd, se] = cellfun(@MMath.MeanStats, Q);
            n = accumarray(subs, 1, [nBins 1]);
            
            if strcmp(qName, 'angsd')
                m = sd;
                sd(:) = NaN;
                se(:) = NaN;
                bootfun = @nanstd;
            else
                bootfun = @nanmean;
            end
            
            if aCI
                nboot = max(1e3, 1/aCI*20);
                ci = cellfun(@(x,y) MMath.BootCI(nboot, {bootfun, x}, 'Groups', y, 'Alpha', aCI), ...
                    Q, I, 'Uni', false);
                ci = cat(2, ci{:})';
            else
                ci = [m-se, m+se];
            end
            
            stats = cat(2, m, sd, n, ci);
        end
        
        function [opto, ctrl] = ComputeRate_Old(trigTb, lickObj, tEdges, aCI, hbInd)
            % Compute lick or touch rate for each time bin
            % Inputs
            %   aCI     Alpha of bootstrap CI (e.g. aCI = 0.05)
            %   hbInd   Indices for hierarchical bootstrap CI. Each trial has an index.
            % Each output is a t-by-s-by-p matrix
            %   t is the number of time bins
            %   s is three statistics: mean, lower CI, upper CI
            %   p is three manipulation periods
            
            if ~exist('aCI', 'var')
                aCI = 0;
            end
            if ~exist('hbInd', 'var')
                hbInd = cell(size(lickObj));
            end
            
            % For opto
            opto = zeros(size(tEdges,1)-1, 3, width(trigTb));
            for i = 1 : width(trigTb)
                licks = lickObj{i};
                t0 = trigTb{i,i}{1};
                tLicks = cellfun(@(x,y) double(x)-y, licks, num2cell(t0), 'Uni', false);
                opto(:,:,i) = SL.Opto.RateMeanCI(tLicks, tEdges(:,i), aCI, hbInd{i});
            end
            
            % For non-opto
            ctrl = zeros(size(tEdges,1)-1, 3, width(trigTb));
            for i = 1 : width(trigTb)
                licks = lickObj{4};
                t0 = trigTb{4,i}{1};
                tLicks = cellfun(@(x,y) double(x)-y, licks, num2cell(t0), 'Uni', false);
                ctrl(:,:,i) = SL.Opto.RateMeanCI(tLicks, tEdges(:,i), aCI, hbInd{4});
            end
        end
        
        function mci = RateMeanCI_Old(xx, edges, aCI, hbInd)
            % Inputs
            %   xx      n-by-1 cell array of lick times where n is the number of trials
            % Outputs
            %   mci     t-by-3 matrix where t is the number of time bins, 3 is for mean, lower CI, higher CI
            
            % Compute histogram for each trial
            n = zeros(numel(xx), numel(edges)-1);
            for j = 1 : size(n,1)
                n(j,:) = histcounts(xx{j}, edges, 'Normalization', 'countdensity');
            end
            
            m = mean(n);
            if aCI
                % Compute bootstrap CI
                ci = MMath.BootCI(max(1e3, 1/aCI*20), {@(x) mean(x)', n}, 'Groups', hbInd, ...
                    'Alpha', aCI, 'Options', statset('UseParallel', true));
%                 ci = zeros(2, size(n,2));
%                 for k = 1 : size(n,2)
%                     ci(:,k) = bootci(max(1e3, 1/pCI*20), {@mean, n(:,k)}, ...
%                         'Alpha', pCI, 'Options', statset('UseParallel', false), 'type', 'bca');
%                 end
            else
                % Duplicate mean as placeholder
                ci = [m; m];
            end
            mci = [m; ci]';
        end
        
        function s = SliceStats(s, tWin)
            % 
            %   Input s is an output of QuantifyPerf
            
            supportedFields = {'len', 'ang', 'angSD', 'angAbs', 'dAng', 'rLick', 'rTouch'};
            fieldNames = fieldnames(s);
            
            for i = 1 : numel(fieldNames)
                fn = fieldNames{i};
                if strcmp(fn, 'info')
                    continue;
                end
                assert(ismember(fn, supportedFields), '%s is not a supported field name', fn);
                
                q = s.(fn);
                tEdges = q.tEdges;
                iEdges = tEdges >= tWin(1) & tEdges <= tWin(2);
                
                
                tBins = tEdges(1:end-1,:) + diff(tEdges)/2;
                iBins = tBins > tWin(1) & tBins < tWin(2);
                iBins = permute(iBins, [1 3 2]);
                
                varNames = {'opto', 'ctrl', 'optoBoot', 'ctrlBoot'};
                for k = 1 : numel(varNames)
                    vn = varNames{k};
                    v = q.(vn);
                    q.(vn) = index3d(v, repmat(iBins, [1 size(v,2) 1]));
                end
                s.(fn) = q;
            end
            
            function vout = index3d(vin, I)
                d = size(vin);
                d(1) = sum(I(:,1,1));
                vout = zeros(d);
                vout(:) = vin(I);
            end
        end
        
        function result = ComputeAreaStats(trigTb, lickObj, optoDur)
            
            % Compute lick stats
            for i = width(trigTb) : -1 : 1
                sOpto(i) = computeStats(lickObj{i}, trigTb{i,i}{1}, optoDur(i));
                sNone(i) = computeStats(lickObj{4}, trigTb{4,i}{1}, optoDur(i));
            end
            
            function result = computeStats(lt, t0, dur)
                t1 = t0 + dur;
                r = zeros(size(lt));
                for n = 1 : length(lt)
                    isInWin = lt{n} > t0(n) & lt{n} <= t1(n);
                    r(n) = sum(isInWin);
                end
                result.r = r;
                result.r_mean = mean(r);
                result.r_sem = MMath.StandardError(r);
                result.r_std = std(r);
                result.r_median = median(r);
                result.r_prct25 = prctile(r,25);
                result.r_prct75 = prctile(r,75);
            end
            
            % Statistics
            tbOpto = struct2table(sOpto);
            tbNone = struct2table(sNone);
            
            tbDiff = table();
            tbDiff.r_med = tbOpto.r_median - tbNone.r_median;
            tbDiff.r_mean_ratio = tbOpto.r_mean ./ tbNone.r_mean;
            for i = 1:length(sOpto)
                [tbDiff.r_med_pval(i), ~, tbDiff.r_med_stats{i}] = ranksum(tbOpto.r{i}, tbNone.r{i});
                [tbDiff.r_mean_pval(i), tbDiff.r_mean(i), tbDiff.r_mean_stats{i}] = ...
                    permutationTest(tbOpto.r{i}, tbNone.r{i}, 1e4);
            end
            
            % Organizing outputs
            result.diffTable = tbDiff;
            result.optoTable = tbOpto;
            result.noneTable = tbNone;
        end
        
    end
end