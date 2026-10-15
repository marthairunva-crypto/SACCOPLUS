part of 'generated.dart';

class ListMyAccountsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListMyAccountsVariablesBuilder(this._dataConnect, );
  Deserializer<ListMyAccountsData> dataDeserializer = (dynamic json)  => ListMyAccountsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListMyAccountsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListMyAccountsData, void> ref() {
    
    return _dataConnect.query("ListMyAccounts", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListMyAccountsAccounts {
  final String id;
  final double totalSavings;
  final double outstandingLoans;
  ListMyAccountsAccounts.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  totalSavings = nativeFromJson<double>(json['totalSavings']),
  outstandingLoans = nativeFromJson<double>(json['outstandingLoans']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyAccountsAccounts otherTyped = other as ListMyAccountsAccounts;
    return id == otherTyped.id && 
    totalSavings == otherTyped.totalSavings && 
    outstandingLoans == otherTyped.outstandingLoans;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, totalSavings.hashCode, outstandingLoans.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['totalSavings'] = nativeToJson<double>(totalSavings);
    json['outstandingLoans'] = nativeToJson<double>(outstandingLoans);
    return json;
  }

  ListMyAccountsAccounts({
    required this.id,
    required this.totalSavings,
    required this.outstandingLoans,
  });
}

@immutable
class ListMyAccountsData {
  final List<ListMyAccountsAccounts> accounts;
  ListMyAccountsData.fromJson(dynamic json):
  
  accounts = (json['accounts'] as List<dynamic>)
        .map((e) => ListMyAccountsAccounts.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyAccountsData otherTyped = other as ListMyAccountsData;
    return accounts == otherTyped.accounts;
    
  }
  @override
  int get hashCode => accounts.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['accounts'] = accounts.map((e) => e.toJson()).toList();
    return json;
  }

  ListMyAccountsData({
    required this.accounts,
  });
}

