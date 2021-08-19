

#'Tree-based Moving Average (tbma)
#'
#'The tbma() function is used for forecasting problems with predictors. With the help of integrating the moving average approach to tree-based ensemble approach, the function handles the correlations and autocorrelations in time series data. The tree-based ensemble models in the tbma() function is provided by the ranger() function from the 'ranger' package (Marvin N. Wright & Andreas Ziegler, 2017).
#'
#'@param formula Object of class formula
#'@param train A data.table object
#'@param test A data.table object
#'@param prediction_type Prediction type can be either "point" or "probabilistic". In case of "probabilistic", percentiel parameter is required.
#'@param percentile Percentile of the probabilistic forecasts if the prediction type is "probabilistic". Percentile paramater can take multiple values between 0 and 1 in a vector.
#'@param group_id Gorup identity parameter is required to filter the data that is going to be used for prediction of a test observations. Group identity parameter is optional to use and usually one of the categorical variables has significant effect on the response variable.
#'@param horizon Horizon parameter filters the train data that is going to be used for forecasting a test observations. The last n train observation is used for forecasting in case of horizon is n. Default value is number of observations in the train set which means no filtering.
#'@param splitrule Splitrule determines the process of splitting. It can be "extratrees","variance", or "maxstat". See the documentation of the 'ranger' package for details.
#'@param always_split_variables Vector of column names indicating the colums that should be selected as candidate variables for splitting. See the documentation of the 'ranger' package for details.
#'@param min_node_size Minimum node size allowed in terminal nodes of decesion trees.
#'@param max_depth Maximum depth of decision trees. See the documentation of the 'ranger' package for details.
#'@param num_trees Number of trees
#'@param mtry Number of variables selected as candidate varibles for splitting. See the documentation of the 'ranger' package for details.
#'@param ma_order Order of the movinh average part of the TBMA model. Default is 2. High order parameter can lead NA forecasts.
#' @return A data.table object. In case of point forecasting, a column called "prediction" is added to the data table that contains the columns mentioned in the formula. In case of probabilistic forecasting, columns named with the percentile values are added to thr data table that contains the columns mentioned in the formula.
#' @export
#' @import data.table
#' @import zoo
#' @import ranger
#' @import RcppRoll
#' @import stats
#' @import utils
#'
#' @examples
#' library(datasets)
#' library(data.table)

#' data(airquality)
#' summary(airquality)

#' airquality<-as.data.table(airquality)
#' airquality[complete.cases(airquality)]

#' train <- airquality[1:102,]
#' test <- airquality[103:nrow(airquality), ]

#' test_data_with_predictions<-tbma(Temp ~ .,train = train,test = test,
#' prediction_type = "point",horizon=100,ma_order = 2)
#'

##' @references
##' \itemize{
##'   \item Wright, M. N. & Ziegler, A. (2017). ranger: A fast implementation of random forests for high dimensional data in C++ and R. J Stat Softw 77:1-17. \url{https://doi.org/10.18637/jss.v077.i01}.
##'   \item Matt Dowle and Arun Srinivasan (2019). data.table: Extension of `data.frame`. R package version 1.12.8. \url{https://CRAN.R-project.org/package=data.table}
##'   }


tbma<-function(formula,train,test,prediction_type="point",percentile=c(0.25,0.5,0.75),group_id=NULL,horizon=nrow(train),splitrule="extratrees",always_split_variables=NULL,min_node_size=5,max_depth=NULL,num_trees=100,ma_order=2,mtry=round(sqrt(ncol(train)))){

  Order<-NULL
  response<-NULL
  basenames<-NULL
  value<-NULL
  id<-NULL
  variable<-NULL
  candidate_forecast<-NULL

  if(length(group_id)>1){print("pelase enter only one column name as group identity")}



  #subset the data according to the formula
  train<-as.data.table(model.frame(formula,data = train))
  test<-as.data.table(model.frame(formula,data = test))
  train[,Order:=1:nrow(train)]
  test[,Order:=(nrow(train)+1):(nrow(test)+nrow(train))]

  #give the gruop_id column the "group_id" name
  colnames(train)[colnames(train)==group_id] <- "group_id"
  colnames(test)[colnames(test)==group_id] <- "group_id"


  #fit decision trees
  if(is.null(group_id)){
    fit=ranger(formula, data = train, num.trees = num_trees, importance = "impurity", always.split.variables=c(always_split_variables),replace=TRUE,
               splitrule=splitrule,mtry = mtry, keep.inbag=TRUE,num.random.splits=5,num.threads=4,min.node.size = min_node_size,max.depth = max_depth)
  } else{
    fit=ranger(formula, data = train, num.trees = num_trees, importance = "impurity", always.split.variables=c("group_id",always_split_variables),replace=TRUE,
               splitrule=splitrule,mtry = mtry, keep.inbag=TRUE,num.random.splits=5,num.threads=4,min.node.size = min_node_size,max.depth = max_depth)
  }

  #prepare data
  temporary<-copy(test)
  response_col_name<-formula[[2]]
  colnames(train)[colnames(train)==response_col_name] <- "response"
  colnames(test)[colnames(test)==response_col_name] <- "response"
  test[,response:=NA]

  #determine the terminal nodes of inbag train observations
  inbag_terminals=predict(fit,train,predict.all=TRUE,type='terminalNodes')$predictions
  inbag = data.table(do.call(cbind, fit$inbag.counts))
  inbag[inbag==0]=NA
  inbag[!is.na(inbag)]=1
  inbag_terminals=inbag_terminals*as.matrix(inbag)
  baseline_train=data.table(train[,list(Order,response,group_id)],inbag_terminals)

  #apply horizon parameter (select the last n observation from the train set)
  if(!is.null(horizon)){
    baseline_train<-tail(baseline_train,n=horizon)
  }


  #determine the terminal nodes of test observations
  test_terminals=predict(fit,test,predict.all=TRUE,type='terminalNodes')$predictions
  baseline_test=data.table(test[,list(Order,response,group_id)],test_terminals)

  #combine the infromation of leaf nodes of inbah ang test observations
  baseline=rbind(baseline_train,baseline_test)
  if(is.null(group_id)){
    baseline=melt(baseline,id.vars=c('Order',"response"),measure_vars=basenames[!(basenames %in% c('Order',"response","group_id"))])
  }else{
    baseline=melt(baseline,id.vars=c('Order',"response","group_id"),measure_vars=basenames[!(basenames %in% c('Order',"response","group_id"))])
  }

  baseline=baseline[order(Order)]
  baseline=baseline[!is.na(value)]

  #determine groups based on tree nodes and group identity parameter
  if(is.null(group_id)){
    setDT(baseline)[, id := .GRP, by=list(variable,value)]
  } else{
    setDT(baseline)[, id := .GRP, by=list(variable,value,group_id)]}

  #apply moving average
  baseline[,candidate_forecast:=RcppRoll::roll_meanr(c(response),ma_order,fill = NA,na.rm = F),by=id]
  baseline[,candidate_forecast := shift(candidate_forecast, fill = NA,n=1), by = id]

  #seperate the test data from the combined inbag and test data
  test_results<-baseline[Order %in% test$Order ]

  #fill some of the candidate forecasts with the same id candidate forecasts
  test_results=test_results[order(Order)]
  test_results[,candidate_forecast:=na.locf(candidate_forecast, na.rm = FALSE),by=id]

  if(prediction_type=="point"){
    #find the median of the candidate forecasts for each test observation
    result=test_results[,list(prediction=median(candidate_forecast,na.rm=T)),by=list(Order,response)]

    #order the test data
    result[,response:=NULL]
    result=merge(temporary,result,by="Order")
    result=result[order(Order)]
  }



  if(prediction_type=="probabilistic"){
    result=test_results[,list(prediction=quantile(candidate_forecast,percentile[1],na.rm = TRUE)),by=list(Order)]
    colnames(result)[colnames(result)=="prediction"] <- as.character(paste(100*percentile[1], 'percentile', sep = '_'))
    if(length(percentile>1)){
      for(i in 2:length(percentile)){
        #find the percentile of the candidate forecasts for each test observation
        temp1<-test_results[,list(prediction=quantile(candidate_forecast,percentile[i],na.rm = TRUE)),by=list(Order)]
        result[,as.character(paste(100*percentile[i], 'percentile', sep = '_'))]<-temp1$prediction
      }
    }
    #order the test data
    result=merge(temporary,result,by="Order")
    result=result[order(Order)]
  }

  return(result)

}
