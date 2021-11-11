classdef MSF
    %MSF Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods(Static)
        function y = RampMod(t, tLow, tHigh)
            
            %{
            a*x + b*y = 1;
            [tLow 0; tHigh 1]*[a b]' = [1 1]';
            y = -a/b*x + 1/b;
            %}
            
            ab = [tLow 0; tHigh 1] \ [1 1]';
            
            f = @(x) -ab(1)/ab(2)*x + 1/ab(2);
            
            y = f(t);
            y(y<0) = 0;
            y(y>1) = 1;
        end
    end
    
end

