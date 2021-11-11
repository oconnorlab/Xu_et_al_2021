classdef Numb
    %NUMB Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        maxTime = 30*60; % min * seconds/min
        maxTrial = Inf;
        colorSaline = [0 0 0];
        colorLido = [.6 .6 .6];
    end
    
    methods(Static)
        function [aTb, isComplete] = RmIncomplete(aTb)
            % Remove animals that do not have both control and numbing session
            for i = height(aTb) : -1 : 1
                isComplete(i) = all(arrayfun(@(x) x.numEpochs, aTb.se{i}));
            end
            aTb = aTb(isComplete,:);
        end
        
        function s = ControlStats(se, statName)
            % Compute stats for tongue numbing experiments
            
            switch statName
                case 'pre_seq_time'
                    [t, val] = SL.Behav.PreSeqTimeOverTrials(se);
                case 'pre_seq_miss'
                    [t, val] = SL.Behav.PreSeqMissOverTrials(se);
                case 'seq_miss'
                    [t, val] = SL.Behav.SeqMissOverTrials(se);
                otherwise
                    error('''%s'' is not a valid statType', statName);
            end
            
            isInclude = t < SL.Numb.maxTime;
            maxTrial = min(numel(t), SL.Numb.maxTrial);
            isInclude(maxTrial+1:end) = false;
            t = t(isInclude);
            sp = val(isInclude);
            
            s.t = t;
            s.sample = sp;
            [s.mean, s.sd, ~, s.ci] = MMath.MeanStats(sp);
            [s.median, s.qt, s.ad] = MMath.MedianStats(sp);
        end
        
        function PlotSessions(aTb, statName)
            % Plot overlay of #misses as a function of trial time from lidocaine and control session
            
            nRow = 3;
            nCol = 4;
            k = 0;
            cc = [SL.Numb.colorSaline; SL.Numb.colorLido];
            
            for i = 1 : height(aTb)
                % Compute #misses per trial
                switch statName
                    case 'seq_miss'
                        [tt, nn] = arrayfun(@SL.Behav.SeqMissOverTrials, aTb.se{i}, 'Uni', false);
                    case 'pre_seq_miss'
                        [tt, nn] = arrayfun(@SL.Behav.PreSeqMissOverTrials, aTb.se{i}, 'Uni', false);
                    otherwise
                        error('''%s'' is not a valid missType', statName);
                end
                
                % Find maxima to set axes consistently across conditions
                tMax = max(cat(2, tt{:}));
                nMax = max(cat(2, nn{:}));
                
                % Plot sessions in the order of control and lidocaine
                [~, jInd] = sort(aTb.is_numb{i}, 'ascend');
                condStr = {'control', 'lidocaine'};
                
                for j = jInd'
                    k = k + 1;
                    if isempty(aTb.se{i}(j))
                        continue
                    end
                    t = tt{j};
                    n = nn{j};
                    maxTrial = min(SL.Numb.maxTrial, numel(t));
                    tCutoff = min(SL.Numb.maxTime, t(maxTrial));
                    
                    ax = subplot(nRow, nCol, k);
                    stem(t, n, 'o-', 'Color', cc(jInd(j),:)); hold on
                    plot(tCutoff([1 1])', [0 nMax+1]', '--');
                    plot(SL.Numb.maxTime([1 1])', [0 nMax+1]', 'r--');
                    plot(t(maxTrial*[1 1])', [0 nMax+1]', 'b--');
                    ax.Title.String = [statName ', ' aTb.animalId{i} ', ' condStr{jInd(j)}];
                    ax.Title.Interpreter = 'none';
                    ax.XLim = [0 tMax];
                    ax.YLim = [0 nMax+1];
                    ax.XLabel.String = 'Time from trial 1 (s)';
                    ax.YLabel.String = '# of miss';
                    MPlot.Axes(ax);
                end
            end
        end
        
        function PlotTime2Engage(aTb)
            % Plot the time taken from the end of iso to active licking
            
            % Only use animals that have complete data
            aTb = SL.Numb.RmIncomplete(aTb);
            
            % Prepare data
            t2e = cat(2, aTb.t2engage{:});
            t2e = t2e([2 1],:); % make ctrl in the first row
            [m, sd, se] = MMath.MeanStats(t2e, 2);
            [~, ~, ~, ci] = MMath.MeanStats(t2e(2,:)-t2e(1,:), 2, 'Alpha', 0.01);
            x = [1 2]';
            
            % Plot
            bar(x, m, 'FaceColor', 'none'); hold on
            plot(x, t2e, 'Color', .6*[1 1 1]); 
            errorbar(x, m, se, 'k');
            ax = gca;
            if ~(ci(1) < 0 && ci(2) > 0)
                plot(mean(x), ax.YLim(2), 'k*');
            end
            ax.XTick = x;
            ax.XTickLabel = {'Saline', 'Lidocaine'};
            ax.YLabel.String = 'min';
            ax.Title.String = 'Time to engage';
            MPlot.Axes(ax);
        end
        
    end
end

