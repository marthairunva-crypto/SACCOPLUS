part of 'generated.dart';

class ListLoanRepaymentsVariablesBuilder {
  String loanId;

  final FirebaseDataConnect _dataConnect;
  ListLoanRepaymentsVariablesBuilder(this._dataConnect, {required  this.loanId,});
  Deserializer<ListLoanRepaymentsData> dataDeserializer = (dynamic json)  => ListLoanRepaymentsData.fromJson(jsonDecode(json));
  Serializer<ListLoanRepaymentsVariables> varsSerializer = (ListLoanRepaymentsVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<ListLoanRepaymentsData, ListLoanRepaymentsVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListLoanRepaymentsData, ListLoanRepaymentsVariables> ref() {
    ListLoanRepaymentsVariables vars= ListLoanRepaymentsVariables(loanId: loanId,);
    return _dataConnect.query("ListLoanRepayments", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class ListLoanRepaymentsLoanRepayments {
  final double amountPaid;
  final Timestamp paymentDate;
  ListLoanRepaymentsLoanRepayments.fromJson(dynamic json):
  
  amountPaid = nativeFromJson<double>(json['amountPaid']),
  paymentDate = Timestamp.fromJson(json['paymentDate']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListLoanRepaymentsLoanRepayments otherTyped = other as ListLoanRepaymentsLoanRepayments;
    return amountPaid == otherTyped.amountPaid && 
    paymentDate == otherTyped.paymentDate;
    
  }
  @override
  int get hashCode => Object.hashAll([amountPaid.hashCode, paymentDate.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['amountPaid'] = nativeToJson<double>(amountPaid);
    json['paymentDate'] = paymentDate.toJson();
    return json;
  }

  ListLoanRepaymentsLoanRepayments({
    required this.amountPaid,
    required this.paymentDate,
  });
}

@immutable
class ListLoanRepaymentsData {
  final List<ListLoanRepaymentsLoanRepayments> loanRepayments;
  ListLoanRepaymentsData.fromJson(dynamic json):
  
  loanRepayments = (json['loanRepayments'] as List<dynamic>)
        .map((e) => ListLoanRepaymentsLoanRepayments.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListLoanRepaymentsData otherTyped = other as ListLoanRepaymentsData;
    return loanRepayments == otherTyped.loanRepayments;
    
  }
  @override
  int get hashCode => loanRepayments.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['loanRepayments'] = loanRepayments.map((e) => e.toJson()).toList();
    return json;
  }

  ListLoanRepaymentsData({
    required this.loanRepayments,
  });
}

@immutable
class ListLoanRepaymentsVariables {
  final String loanId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  ListLoanRepaymentsVariables.fromJson(Map<String, dynamic> json):
  
  loanId = nativeFromJson<String>(json['loanId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListLoanRepaymentsVariables otherTyped = other as ListLoanRepaymentsVariables;
    return loanId == otherTyped.loanId;
    
  }
  @override
  int get hashCode => loanId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['loanId'] = nativeToJson<String>(loanId);
    return json;
  }

  ListLoanRepaymentsVariables({
    required this.loanId,
  });
}

