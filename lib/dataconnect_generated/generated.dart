library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_member_data.dart';

part 'update_member_profile.dart';

part 'delete_member.dart';

part 'get_my_profile.dart';

part 'create_account.dart';

part 'update_account_savings.dart';

part 'delete_account.dart';

part 'list_my_accounts.dart';

part 'create_loan.dart';

part 'update_loan_status.dart';

part 'delete_loan.dart';

part 'get_loan_details.dart';

part 'add_repayment.dart';

part 'update_repayment.dart';

part 'delete_repayment.dart';

part 'list_loan_repayments.dart';

part 'record_transaction.dart';

part 'update_transaction_notes.dart';

part 'delete_transaction.dart';

part 'list_my_transactions.dart';







class ExampleConnector {
  
  
  CreateMemberDataVariablesBuilder createMemberData ({required String fullName, required String email, required String phone, }) {
    return CreateMemberDataVariablesBuilder(dataConnect, fullName: fullName,email: email,phone: phone,);
  }
  
  
  UpdateMemberProfileVariablesBuilder updateMemberProfile ({required String fullName, }) {
    return UpdateMemberProfileVariablesBuilder(dataConnect, fullName: fullName,);
  }
  
  
  DeleteMemberVariablesBuilder deleteMember () {
    return DeleteMemberVariablesBuilder(dataConnect, );
  }
  
  
  GetMyProfileVariablesBuilder getMyProfile () {
    return GetMyProfileVariablesBuilder(dataConnect, );
  }
  
  
  CreateAccountVariablesBuilder createAccount ({required double totalSavings, }) {
    return CreateAccountVariablesBuilder(dataConnect, totalSavings: totalSavings,);
  }
  
  
  UpdateAccountSavingsVariablesBuilder updateAccountSavings ({required String id, required double totalSavings, }) {
    return UpdateAccountSavingsVariablesBuilder(dataConnect, id: id,totalSavings: totalSavings,);
  }
  
  
  DeleteAccountVariablesBuilder deleteAccount ({required String id, }) {
    return DeleteAccountVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListMyAccountsVariablesBuilder listMyAccounts () {
    return ListMyAccountsVariablesBuilder(dataConnect, );
  }
  
  
  CreateLoanVariablesBuilder createLoan ({required double principal, required double interest, required DateTime dueDate, }) {
    return CreateLoanVariablesBuilder(dataConnect, principal: principal,interest: interest,dueDate: dueDate,);
  }
  
  
  UpdateLoanStatusVariablesBuilder updateLoanStatus ({required String id, required String status, }) {
    return UpdateLoanStatusVariablesBuilder(dataConnect, id: id,status: status,);
  }
  
  
  DeleteLoanVariablesBuilder deleteLoan ({required String id, }) {
    return DeleteLoanVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetLoanDetailsVariablesBuilder getLoanDetails ({required String id, }) {
    return GetLoanDetailsVariablesBuilder(dataConnect, id: id,);
  }
  
  
  AddRepaymentVariablesBuilder addRepayment ({required String loanId, required double amount, }) {
    return AddRepaymentVariablesBuilder(dataConnect, loanId: loanId,amount: amount,);
  }
  
  
  UpdateRepaymentVariablesBuilder updateRepayment ({required String id, required double amount, }) {
    return UpdateRepaymentVariablesBuilder(dataConnect, id: id,amount: amount,);
  }
  
  
  DeleteRepaymentVariablesBuilder deleteRepayment ({required String id, }) {
    return DeleteRepaymentVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListLoanRepaymentsVariablesBuilder listLoanRepayments ({required String loanId, }) {
    return ListLoanRepaymentsVariablesBuilder(dataConnect, loanId: loanId,);
  }
  
  
  RecordTransactionVariablesBuilder recordTransaction ({required double amount, required String type, }) {
    return RecordTransactionVariablesBuilder(dataConnect, amount: amount,type: type,);
  }
  
  
  UpdateTransactionNotesVariablesBuilder updateTransactionNotes ({required String id, required String notes, }) {
    return UpdateTransactionNotesVariablesBuilder(dataConnect, id: id,notes: notes,);
  }
  
  
  DeleteTransactionVariablesBuilder deleteTransaction ({required String id, }) {
    return DeleteTransactionVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListMyTransactionsVariablesBuilder listMyTransactions () {
    return ListMyTransactionsVariablesBuilder(dataConnect, );
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'saccoplus',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    
    CacheSettings cacheSettings = CacheSettings(
      maxAge: Duration(milliseconds:0),
      storage: CacheStorage.persistent,
    );
    
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            
            cacheSettings: cacheSettings,
            
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
