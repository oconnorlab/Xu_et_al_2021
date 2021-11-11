classdef Reward
    methods(Static)
        function s = GetExampleInfo(keystr)
            
            unitInd = [];
            trialNum = [];
            areaName = '';
            sessionDatetime = '';
            
            ALM = {'ALM', 'MX170903 2018-03-04'};
            
            if ismember(keystr, ALM)
                [areaName, sessionDatetime] = ALM{:};
                unitInd = [10 17];
            else
                warning('%s is not an example session.', keystr);
            end
            
            s.areaName = areaName;
            s.sessionDatetime = sessionDatetime;
            s.unitInd = unitInd;
            s.trialNum = trialNum;
        end
        
        function PlotProbLick(seTb)
            % Project data to basis vectors and plot as a function of time
            cla;
            for j = 1 : height(seTb)
                t = seTb.time{j};
                p = 1 - seTb.stim{j}(:,3,5);
                plot(t, p, seTb.line{j}, 'Color', seTb.color(j,:), 'LineWidth', 1);
            end
            dt = t(2) - t(1);
            ax = MPlot.Axes(gca);
            ax.XLim = [t(1)-dt/2 t(end)+dt/2];
            ax.XTick = [-.5 0 .5];
            ax.YLim = [0 1];
            ylabel('P(lick)');
        end
        
        function FormatDiffAxes(ax, varName)
            % Format the axes according to the variable being plotted
            MPlot.Axes(ax);
            switch varName
                case '\tau'
                    ax.YLim = [-1 1]*.2;
                case 'I'
                    ax.YLim = [-1 1]*.7;
                    ax.YTick = 0;
                case '\theta'
                    ax.YLim = [0 1]*30;
                    ax.YTick = [0 1]*30;
                    ax.YLabel.String = 'degree';
                case 'L'
                    ax.YLim = [0 2.5];
                    ax.YLabel.String = 'mm';
                case 'L'''
                    ax.YLim = [-1 1] * 70;
                    ax.YLabel.String = 'mm/s';
            end
            if startsWith(varName, 'PC')
                ax.YTick = [];
            end
        end
    end
end

