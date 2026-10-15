part of 'generated.dart';

class ListMyTransactionsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListMyTransactionsVariablesBuilder(this._dataConnect, );
  Deserializer<ListMyTransactionsData> dataDeserializer = (dynamic json)  => ListMyTransactionsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListMyTransactionsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListMyTransactionsData, void> ref() {
    
    return _dataConnect.query("ListMyTransactions", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListMyTransactionsTransactions {
  final double amount;
  final String type;
  final Timestamp date;
  ListMyTransactionsTransactions.fromJson(dynamic json):
  
  amount = nativeFromJson<double>(json['amount']),
  type = nativeFromJson<String>(json['type']),
  date = Timestamp.fromJson(json['date']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyTransactionsTransactions otherTyped = other as ListMyTransactionsTransactions;
    return amount == otherTyped.amount && 
    type == otherTyped.type && 
    date == otherTyped.date;
    
  }
  @override
  int get hashCode => Object.hashAll([amount.hashCode, type.hashCode, date.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['amount'] = nativeToJson<double>(amount);
    json['type'] = nativeToJson<String>(type);
    json['date'] = date.toJson();
    return json;
  }

  ListMyTransactionsTransactions({
    required this.amount,
    required this.type,
    required this.date,
  });
}

@immutable
class ListMyTransactionsData {
  final List<ListMyTransactionsTransactions> transactions;
  ListMyTransactionsData.fromJson(dynamic json):
  
  transactions = (json['transactions'] as List<dynamic>)
        .map((e) => ListMyTransactionsTransactions.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyTransactionsData otherTyped = other as ListMyTransactionsData;
    return transactions == otherTyped.transactions;
    
  }
  @override
  int get hashCode => transactions.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['transactions'] = transactions.map((e) => e.toJson()).toList();
    return json;
  }

  ListMyTransactionsData({
    required this.transactions,
  });
}

