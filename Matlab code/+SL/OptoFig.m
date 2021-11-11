classdef OptoFig
    methods(Static)
        function PlotLickQuantTraces(s, i, qName, ops)
            % s         Output from SL.Opto.QuantifyPerf, stored in aResults
            % i         The index of period to plot
            % qName     Field name in s for the quantity to plot
            
            d = s.(qName);
            
            % Compute CI
            d = SL.Opto.AppendCI(d, ops.aCI);
            
            % Organize data
            tEdges = d.tEdges(:,i);
            t = tEdges(1:end-1) + diff(tEdges)/2;
            opto = d.opto(:,:,i);
            ctrl = d.ctrl(:,:,i);
            
            % Plot
            switch ops.style
                case 'mouse_1s'
                    ops.lineAlpha = .25;
                    ops.lineWidth = .5;
                    ops.plotSD = false;
                    ops.plotCI = false;
                    ops.plotSig = false;
                    ops.plotOptoBar = false;
                case 'mean_1s'
                    ops.lineAlpha = 1;
                    ops.lineWidth = 1;
                    ops.plotSD = false;
                    ops.plotCI = true;
                    ops.plotSig = false;
                    ops.plotOptoBar = false;
            end
            
            ax = gca;
            hold on;
            
            if ops.plotSD
                MPlot.ErrorShade(t, opto(:,1), opto(:,2), 'Color', SL.Param.optoColor, 'Alpha', .15);
                MPlot.ErrorShade(t, ctrl(:,1), ctrl(:,2), 'Color', [0 0 0], 'Alpha', .15);
            end
            if ops.plotCI
                MPlot.ErrorShade(t, opto(:,1), opto(:,5), opto(:,4), ...
                    'IsRelative', false, 'Color', SL.Param.optoColor, 'Alpha', .15);
                MPlot.ErrorShade(t, ctrl(:,1), ctrl(:,5), ctrl(:,4), ...
                    'IsRelative', false, 'Color', [0 0 0], 'Alpha', .15);
            end
            plot(t, opto(:,1), 'Color', [SL.Param.optoColor ops.lineAlpha], 'LineWidth', ops.lineWidth);
            plot(t, ctrl(:,1), 'Color', [0 0 0 ops.lineAlpha], 'LineWidth', ops.lineWidth);
            
            switch qName
                case 'angSD'
                    ylabel('SD(angle)');
                    ax.YLim = [0 40];
                    ax.YTick = 0:20:40;
                case 'angAbs'
                    ylabel('abs(angle)');
                    ax.YLim = [0 40];
                    ax.YTick = 0:20:40;
                case 'ang'
                    ylabel('Angle');
                    ax.YLim = [-30 50];
                    ax.YTick = -30:30:30;
                case 'dAng'
                    ylabel('dAngle');
                    ax.YLim = [-40 40];
                    ax.YTick = -40:20:40;
                case 'len'
                    ylabel('L (mm)');
                    ax.YLim = [0 4];
                    ax.YTick = 0:2:4;
            end
            
            w = diff(ax.YLim)*.05;
            if ops.plotOptoBar
                MPlot.Blocks([0 ops.optoDur], ax.YLim([2 2])-[w 0], SL.Param.optoColor);
            end
            if ops.plotSig
                MPlot.GroupRibbon(pBin, ax.YLim([2 2])-[3*w 2*w], @(x) flip(bone(x)), ...
                    'Groups', 1:(numel(lvl)-1), 'IndVal', t);
            end
            ax.XLim = [tEdges(1) tEdges(end)];
            ax.TickDir = 'out';
            title([s.info.area ' ' ops.optoType{i}]);
            box off
        end
        
        function PlotLickRateTraces(s, i, rName, ops)
            % s         Output from SL.Opto.QuantifyPerf, stored in aResults
            % i         The index of period to plot
            % rName     Field name in s for the type of rate to plot
            
            d = s.(rName);
            
            % Compute CI
            d = SL.Opto.AppendCI(d, ops.aCI);
            
            % Organize data
            tEdges = d.tEdges(:,i);
            t = tEdges(1:end-1) + diff(tEdges)/2;
            opto = d.opto(:,:,i);
            ctrl = d.ctrl(:,:,i);
            
            % Plotting parameters
            switch rName
                case 'rTouch'
                    lineArgs = {'LineStyle', ':', 'LineWidth', 1};
                case 'rLick'
                    lineArgs = {'LineStyle', '-', 'LineWidth', .5};
            end
            
            % Plot
            ax = MPlot.Axes(gca); hold on
            
            ax.XLim = [tEdges(1) tEdges(end)];
            if i == 1
                ax.YLim = [-.5 9];
            else
                ax.YLim = [-.5 11];
            end
            
            if ops.plotOptoBar
                MPlot.Blocks([0 ops.optoDur], ax.YLim(2).*[.95 1], SL.Param.optoColor);
            end
            
            if ops.plotShade
                MPlot.ErrorShade(t, opto(:,1), opto(:,5), opto(:,4), 'IsRelative', false, 'Color', [0 .6 1], 'Alpha', .15);
                MPlot.ErrorShade(t, ctrl(:,1), ctrl(:,5), ctrl(:,4), 'IsRelative', false, 'Color', [0 0 0], 'Alpha', .15);
            end
            
            plot(t, opto(:,1), 'Color', [0 .6 1], lineArgs{:});
            plot(t, ctrl(:,1), 'Color', [0 0 0], lineArgs{:});
            
            ylabel('Rate (Hz)');
            title([s.info.area ' ' ops.optoType{i}]);
        end
        
        function PlotBars(pooled, mice, qName, mType, ops)
            % pooled        Output from SL.Opto.QuantifyPerf, stored in aResults
            % mice          Output from SL.Opto.QuantifyPerf, stored in aaResults
            % qName         Field name in pooled and mice for the quantity of interest
            % mType         'combined' will plot combined means from all periods
            %               'separate' will plot periods separately
            
            areaName = pooled.info.area;
            disp([areaName ' ' qName]);
            
            % Compute averages and CI
            pooled = SL.Opto.DeriveScalarStats(pooled.(qName), ops.aCI);
            
            % Organize data for average
            if strcmp(mType, 'combined')
                mci = pooled.scalar;
                pVal = pooled.pVal;
            else
                mci = pooled.scalar3;
                pVal = pooled.pVal3;
            end
            pVal = pVal * ops.nCompare;
            disp(pVal);
            pVal(pVal >= 0.05) = .99;
            
            ctrl = permute(mci(1,:,:), [3 2 1]); % to period-by-stats
            mCtrl = ctrl(:,1);
            ciCtrl = ctrl(:,2:3);
            
            opto = permute(mci(2,:,:), [3 2 1]); % to period-by-stats
            mOpto = opto(:,1);
            ciOpto = opto(:,2:3);
            
            nCond = size(opto, 1);
            
            ax = gca;
            hold on;
            
            % Bars
            if nCond == 1
                b(1) = bar(1, mCtrl);
                b(2) = bar(2, mOpto);
            else
                b = bar([mCtrl mOpto]);
            end
            xCtrl = b(1).XEndPoints;
            xOpto = b(2).XEndPoints;
            b(1).FaceColor = 'none';
            b(2).FaceColor = 'none';
            b(2).EdgeColor = SL.Param.optoColor;
            
            % CI
            errorbar(xCtrl, mCtrl, mCtrl-ciCtrl(:,1), ciCtrl(:,2)-mCtrl, 'k.');
            errorbar(xOpto, mOpto, mOpto-ciOpto(:,1), ciOpto(:,2)-mOpto, '.', 'Color', SL.Param.optoColor);
            
            if ~isempty(mice)
                % Compute averages and CI
                mice = cellfun(@(s) SL.Opto.DeriveScalarStats(s.(qName), ops.aCI), mice, 'Uni', false);
                
                % Organize data for mice
                if strcmp(mType, 'combined')
                    mci = cellfun(@(s) s.scalar, mice, 'Uni' ,false);
                else
                    mci = cellfun(@(s) s.scalar3, mice, 'Uni' ,false);
                end
                
                ctrls = cell2mat(cellfun(@(x) x(1,:,:), mci, 'Uni', false)); % mice-by-stats-by-peri
                spCtrl = squeeze(ctrls(:,1,:)); % mice-by-peri
                
                optos = cell2mat(cellfun(@(x) x(2,:,:), mci, 'Uni', false)); % mice-by-stats-by-peri
                spOpto = squeeze(optos(:,1,:)); % mice-by-peri
                
                nMice = numel(mice);
                
                % Plot mice
                xx = [repelem(xCtrl, nMice); repelem(xOpto, nMice)];
                yy = [spCtrl(:) spOpto(:)]';
                plot(xx, yy, 'Color', [0 0 0 .3]);
            end
            
            % Format plot
            ax.XTick = mean([xCtrl; xOpto]);
            ax.XTickLabel = floor(-log10(pVal));
            ax.Title.String = areaName;
            switch qName
                case 'ang'
                    ylabel('Angle');
                    ax.YLim = [-45 60];
                    ax.YTick = -30:30:30;
                case 'len'
                    ylabel('L (mm)');
                    ax.YLim = [1 3.5];
                    ax.YTick = 0:4;
                case 'angSD'
                    ylabel('SD(angle)');
                    ax.YLim = [0 25];
                    ax.YTick = 0:10:30;
                case 'dAng'
                    ylabel('dAngle');
                    ax.YLim = [-40 40];
                    ax.YTick = -40:20:40;
                case 'angAbs'
                    ylabel('Abs(angle)');
                    ax.YLim = [0 35];
                    ax.YTick = 0:10:40;
                case 'rInit'
                    ylabel('r(Init) (Hz)');
                    ax.YLim = [0 9];
                    ax.YTick = 0:2:8;
                case 'rMid'
                    ylabel('r(Mid) (Hz)');
                    ax.YLim = [0 9];
                    ax.YTick = 0:2:8;
                case 'rCons'
                    ylabel('r(Cons) (Hz)');
                    ax.YLim = [0 9];
                    ax.YTick = 0:2:8;
                case 'rLick'
                    ylabel('r (Hz)');
                    ax.YLim = [0 8.5];
                    ax.YTick = 0:2:10;
            end
        end
        
        function s = PrepareBrainOverlayData(aResults, qName, period, ops)
            % aResults      A cell array of output from SL.Opto.QuantifyPerf
            % qName         Field name in pooled and mice for the quantity of interest
            % period        'combined', 'init', 'mid', or 'cons'
            % ops.aCI       Significance level for statistical tests
            % ops.nCompare  The number of multiple comparison to correct
            
            for i = numel(aResults) : -1 : 1
                % Find brain coordinates
                s = aResults{i};
                coor = eval(s.info.coor);
                breg(i) = coor(1);
                lat(i) = coor(2);
                
                % Compute mean and pval for each region
                s = SL.Opto.DeriveScalarStats(s.(qName), ops.aCI);
                
                % Extract data
                switch period
                    case 'combined'
                        mci = s.scalar;
                        pVal = s.pVal;
                    case 'init'
                        mci = s.scalar3(:,:,1);
                        pVal = s.pVal3(1);
                    case 'mid'
                        mci = s.scalar3(:,:,2);
                        pVal = s.pVal3(2);
                    case 'cons'
                        mci = s.scalar3(:,:,3);
                        pVal = s.pVal3(3);
                end
                d(i) = mci(2,1) - mci(1,1); % opto - ctrl
                p(i) = pVal * ops.nCompare;
            end
            
            s = struct;
            s.qName = qName;
            s.period = period;
            s.breg = breg;
            s.lat = lat;
            s.d = d;
            s.p = p;
        end
        
        function PlotBrainOverlay(s)
            % s is output of SL.OptoFig.PlotBrainData
            
            % Unpack variables
            qName = s.qName;
            period = s.period;
            lat = s.lat;
            breg = s.breg;
            d = s.d;
            p = s.p;
            
            for i = numel(p) : -1 : 1
                % Convert pval to dot size
                if p(i) < 1e-3
                    sz(i) = 3;
                elseif p(i) < 1e-2
                    sz(i) = 2;
                elseif p(i) < .05
                    sz(i) = 1;
                else
                    sz(i) = NaN;
                end
            end
            sz = sz * 40;
            
            % Plot brain
            ax = gca; cla
            imageName = 'Allen CCF dorsal view white.tif';
            img = imread(imageName);
            scale = size(img,2)/10; % pixel/mm
            topBreg = 5.45; % mm
            x = (1:size(img,2))' / scale;
            x = x - max(x)/2;
            y = (1:size(img,1))' / scale;
            y = -(y - topBreg);
            image(x, y, img(:,:,1:3)); hold on
            axis equal xy tight off
            
            % Plot scale bar
            plot([0 -1; 0 1]*.5, [-1 0; 1 0]*.5, 'k', 'LineWidth', 1); hold on
%             ax.XLim = [-5 5];
            ax.YLim = [-4 5.5];
            
            % Overlay dots
            scatter(lat, breg, sz, d, 'filled');
            scatter(-lat, breg, sz, d, 'filled');
            colorbar('southoutside');
            colormap(MPlot.PolarMap())
            
            % Format plot
            switch qName
                case 'angSD'
                    ax.Title.String = 'SD(angle) (deg)';
                    caxis(ax, [-1 1]*8);
                case 'angAbs'
                    ax.Title.String = 'Abs(angle) (deg)';
                    caxis(ax, [-1 1]*7);
                case 'len'
                    ax.Title.String = 'Lmax (mm)';
                    caxis(ax, [-1 1]*.5);
                case 'rLick'
                    if strcmp(period, 'init')
                        ax.Title.String = 'rLick(Init) (Hz)';
                        caxis(ax, [-1 1]*5);
                    elseif strcmp(period, 'cons')
                        ax.Title.String = 'rLick(Cons) (Hz)';
                        caxis(ax, [-1 1]*4);
                    end
            end
        end
        
        function AngleSeq(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            hold(ax, 'on');
            [datTb, s, k] = varargin{:};
            
            % Get data
            tTrigTb = datTb(:,{'tInit','tMid','tCons'});
            tTrig = tTrigTb.(k)([k end]);
            licks = datTb.lickObj([k end]);
            for i = 1 : numel(licks)
                t0 = tTrig{i};
                ll = licks{i};
                
                ind = randsample(numel(t0), 50);
                t0 = t0(ind);
                ll = ll(ind);
            	
                ll = cellfun(@(x,y) x-y, ll, num2cell(t0), 'Uni', false);
                licks{i} = cat(1, ll{:});
            end
            
            % Plot angle sequences
            cc = [SL.Param.optoColor; 0 0 0];
            for i = numel(licks) : -1 : 1
                [aML, ~, tML] = licks{i}.AngleAtMaxLength;
                isTouch = licks{i}.IsTouch;
                plot(tML(isTouch), aML(isTouch), '.', 'Color', cc(i,:), 'MarkerSize', 1);
                plot(tML(~isTouch), aML(~isTouch), '.', 'Color', [cc(i,:) .15], 'MarkerSize', 1);
            end
            
            % Plot opto indicator
            y = 135;
            MPlot.Blocks([0 s.info.optoDur], [y y*1.05], SL.Param.optoColor);
            
            ax.XLim = [s.pEdges(1,k) s.pEdges(end,k)];
            ax.YLim = [45 135];
            ax.YTick = 60:30:120;
            ax.YLabel.String = '\theta_{ML} (deg)';
            title([s.info.area ' ' s.info.optoType{k}]);
            MPlot.Axes(ax);
        end
        
        function LengthSeq(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            hold(ax, 'on');
            [datTb, s, k] = varargin{:};
            
            % Get data
            tTrigTb = datTb(:,{'tInit','tMid','tCons'});
            tTrig = tTrigTb.(k)([k end]);
            licks = datTb.lickObj([k end]);
            for i = 1 : numel(licks)
                t0 = tTrig{i};
                ll = licks{i};
                
                ind = randsample(numel(t0), 50);
                t0 = t0(ind);
                ll = ll(ind);
            	
                ll = cellfun(@(x,y) x-y, ll, num2cell(t0), 'Uni', false);
                licks{i} = cat(1, ll{:});
            end
            
            % Plot length sequences
            cc = [SL.Param.optoColor; 0 0 0];
            for i = numel(licks) : -1 : 1
                [ml, ~, tml] = licks{i}.MaxLength;
                isTouch = licks{i}.IsTouch;
                plot(tml(isTouch), ml(isTouch), '.', 'Color', cc(i,:), 'MarkerSize', 1);
                plot(tml(~isTouch), ml(~isTouch), 'o', 'Color', [cc(i,:) .15], 'MarkerSize', 1);
            end
            
            ax.XLim = [s.pEdges(1,k) s.pEdges(end,k)];
            ax.YLim = [0 4.5];
            ax.YTick = 0 : 4;
            ax.YLabel.String = 'L_{max} (mm)';
            MPlot.Axes(ax);
        end
        
        function FormatLickProfile(ax, quantName)
            % 
            switch quantName
                case 'length'
                    ax.YLim = [0 3.5];
                    ax.YTick = 0:4;
                    ax.YTickLabel = ax.YTick;
                    ax.YLabel.String = 'L (mm)';
                case 'angle'
                    plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
                    ax.YLim = [-1 1]*45;
                    ax.YTick = -30:30:30;
                    ax.YTickLabel = ax.YTick;
                    ax.YLabel.String = '\Theta (deg)';
                case 'velocity'
                    ax.YLim = [-300 200];
                    ax.YTick = -200:200:200;
                    ax.YTickLabel = ax.YTick;
                    ax.YLabel.String = 'L'' (mm/s)';
                case 'forceV'
                    plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
                    ax.YLim(1) = -2;
                    ax.YLim(2) = ceil(ax.YLim(2));
                    ax.YTick = [0 5 10];
                    ax.YLabel.String = 'F_{vert} (mN)';
                case 'forceH'
                    plot(ax.XLim', [0 0]', 'Color', [0 0 0 .15]);
                    ax.YLim = [-2 2];
                    ax.YLabel.String = 'F_{hori} (mN)';
            end
        end
        
        function TrialTouch(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, bt] = varargin{:};
            
            hold(ax, 'on');
            touchWin = [bt.lickOn{k}, bt.lickOff{k}];
            MPlot.Blocks(touchWin, ax.YLim, [0 0 0], 'FaceAlpha', 0.1, 'Parent', ax);
            
%             tPos = [bt.posIndex{k}; bt.waterTrig(k)];
%             plot([tPos tPos]', repmat(ax.YLim, [numel(tPos) 1])', 'Color', [0 .7 0]);
        end
        
        function TrialOptoStim(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, adc] = varargin{:};
            
            tADC = adc.time{k};
            opto1 = adc.opto1{k} / SL.Param.vOptoAdcPerMod / 5;
            opto1(end) = 0;
%             opto1 = opto1 * (105-75) + 75;
            
            hold(ax, 'on');
            patch(ax, tADC, opto1, [0 .5 .75], 'FaceAlpha', .5, 'LineStyle', 'none');
            
%             ax.YTick = [];
%             ax.XTick = [];
            ax.XAxis.Visible = 'off';
            ax.YAxis.Visible = 'off';
            MPlot.Axes(ax);
        end
        
        function TrialAngle(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, bt, hsv] = varargin{:};
            
            hold(ax, 'on');
            
            % Check direction
            lickObj = bt.lickObj{k};
            sn = sign(lickObj(end).portPos - lickObj(1).portPos);
            
            % Angle trace
            t = hsv.time{k};
            A = hsv.tongue_bottom_angle{k};
            L = hsv.tongue_bottom_length{k};
            A(L < SL.Param.minLen4Ang) = NaN;
            isOpto = t > bt.opto(k);
            notOpto = [true; ~isOpto(1:end-1)];
            
            plot(ax, t([1 end]), [0 0], 'Color', [0 0 0 .15]);
            plot(ax, t(notOpto), A(notOpto)*sn, 'Color', [0 0 0 .5], 'LineWidth', .5);
            plot(ax, t(isOpto), A(isOpto)*sn, 'Color', [SL.Param.optoColor .5], 'LineWidth', .5);
            
            % Shooting angle
            [Ashoot, ~, tshoot] = lickObj.ShootingAngle();
            isOpto = tshoot > bt.opto(k);
            
            stem(tshoot(~isOpto), Ashoot(~isOpto)*sn, ...
                'ShowBaseLine', 'off', 'Marker', '.', 'Color', [0 0 0], 'LineWidth', .5);
            stem(tshoot(isOpto), Ashoot(isOpto)*sn, ...
                'ShowBaseLine', 'off', 'Marker', '.', 'Color', SL.Param.optoColor, 'LineWidth', .5);
            
            ax.YLim = [-45 45];
            ax.YTick = -45:15:45;
            ax.YTickLabel = {-45, [], [], 0, [], [], 45};
            ax.YLabel.String = '\Theta (deg)';
            MPlot.Axes(ax);
        end
        
        function TrialLength(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, bt, hsv] = varargin{:};
            
            hold(ax, 'on');
            
            % Length trace
            t = hsv.time{k};
            L = hsv.tongue_bottom_length{k};
            isOpto = t > bt.opto(k);
            notOpto = [true; ~isOpto(1:end-1)];
            
            plot(ax, t(notOpto), L(notOpto), 'Color', [0 0 0 .5], 'LineWidth', .5);
            plot(ax, t(isOpto), L(isOpto), 'Color', [SL.Param.optoColor .5], 'LineWidth', .5);
            
            % Max length
            lickObj = bt.lickObj{k};
            [Lmax, ~, tmax] = lickObj.MaxLength();
            isOpto = tmax > bt.opto(k);
            
            stem(tmax(~isOpto), Lmax(~isOpto), ...
                'ShowBaseLine', 'off', 'Marker', '.', 'Color', [0 0 0], 'LineWidth', .5);
            stem(tmax(isOpto), Lmax(isOpto), ...
                'ShowBaseLine', 'off', 'Marker', '.', 'Color', SL.Param.optoColor, 'LineWidth', .5);
            
            ax.YLim = [0 ceil(nanmax(L))];
            ax.YTick = ax.YLim(1) : ax.YLim(2);
            ax.YLabel.String = 'L (mm)';
            MPlot.Axes(ax);
        end
    end
end

