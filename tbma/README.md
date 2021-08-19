
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tbma

<!-- badges: start -->

<!-- badges: end -->

A new tree-based ensemble model that is called tree-based moving average
(TBMA) is provided for time series forecasting problems. The TBMA model
provides point and probabilistic forecasts and uses both of the
tree-based ensemble and MA approaches to consider predictors and time
series components. The suggested model can handle a large number of
numerical and categorical predictors without sacrificing the accuracy
with the help of the tree-based ensemble approach. The integration of
the MA model to a tree-based ensemble approach helps the TBMA model to
capture autocorrelation between observations. With the use of the
tree-based ensemble and MA approaches, the proposed model becomes
multivariate and adapted to time series problems.

## Installation

You can install the released version of tbma from
[GitHub](https://github.com/BurakhanS/tbma) with:

``` r
library(devtools)
install_github("BurakhanS/tbma")
library(tbma)
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(datasets)
library(data.table)
library(tbma)
data(airquality)
summary(airquality)
#>      Ozone           Solar.R           Wind             Temp      
#>  Min.   :  1.00   Min.   :  7.0   Min.   : 1.700   Min.   :56.00  
#>  1st Qu.: 18.00   1st Qu.:115.8   1st Qu.: 7.400   1st Qu.:72.00  
#>  Median : 31.50   Median :205.0   Median : 9.700   Median :79.00  
#>  Mean   : 42.13   Mean   :185.9   Mean   : 9.958   Mean   :77.88  
#>  3rd Qu.: 63.25   3rd Qu.:258.8   3rd Qu.:11.500   3rd Qu.:85.00  
#>  Max.   :168.00   Max.   :334.0   Max.   :20.700   Max.   :97.00  
#>  NA's   :37       NA's   :7                                       
#>      Month            Day      
#>  Min.   :5.000   Min.   : 1.0  
#>  1st Qu.:6.000   1st Qu.: 8.0  
#>  Median :7.000   Median :16.0  
#>  Mean   :6.993   Mean   :15.8  
#>  3rd Qu.:8.000   3rd Qu.:23.0  
#>  Max.   :9.000   Max.   :31.0  
#> 
airquality<-as.data.table(airquality)
airquality[complete.cases(airquality)]
#>      Ozone Solar.R Wind Temp Month Day
#>   1:    41     190  7.4   67     5   1
#>   2:    36     118  8.0   72     5   2
#>   3:    12     149 12.6   74     5   3
#>   4:    18     313 11.5   62     5   4
#>   5:    23     299  8.6   65     5   7
#>  ---                                  
#> 107:    14      20 16.6   63     9  25
#> 108:    30     193  6.9   70     9  26
#> 109:    14     191 14.3   75     9  28
#> 110:    18     131  8.0   76     9  29
#> 111:    20     223 11.5   68     9  30
train <- airquality[1:102,]
test <- airquality[103:nrow(airquality), ]
output<-tbma(Temp ~ .,train = train,test = test,
prediction_type = "point",horizon=100,ma_order = 2)

library(datasets)
#this is the input data
head(airquality,5)
#>    Ozone Solar.R Wind Temp Month Day
#> 1:    41     190  7.4   67     5   1
#> 2:    36     118  8.0   72     5   2
#> 3:    12     149 12.6   74     5   3
#> 4:    18     313 11.5   62     5   4
#> 5:    NA      NA 14.3   56     5   5

#this is the output data (Order and prediction columns are added by the tbma() function)
head(output,5)
#>    Order Temp Ozone Solar.R Wind Month Day prediction
#> 1:    66   86    44     192 11.5     8  12       83.5
#> 2:    67   82    28     273 11.5     8  13       81.5
#> 3:    68   80    65     157  9.7     8  14       85.0
#> 4:    69   77    22      71 10.3     8  16       81.5
#> 5:    70   79    59      51  6.3     8  17       83.5
```

\`\`
