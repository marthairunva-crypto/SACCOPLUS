import { ConnectorConfig, DataConnect, OperationOptions, ExecuteOperationResponse } from 'firebase-admin/data-connect';

export const connectorConfig: ConnectorConfig;

export type TimestampString = string;
export type UUIDString = string;
export type Int64String = string;
export type DateString = string;


export interface Account_Key {
  id: UUIDString;
  __typename?: 'Account_Key';
}

export interface AddRepaymentData {
  loanRepayment_insert: LoanRepayment_Key;
}

export interface AddRepaymentVariables {
  loanId: UUIDString;
  amount: number;
}

export interface CreateAccountData {
  account_insert: Account_Key;
}

export interface CreateAccountVariables {
  totalSavings: number;
}

export interface CreateLoanData {
  loan_insert: Loan_Key;
}

export interface CreateLoanVariables {
  principal: number;
  interest: number;
  dueDate: DateString;
}

export interface CreateMemberDataData {
  member_insert: Member_Key;
}

export interface CreateMemberDataVariables {
  fullName: string;
  email: string;
  phone: string;
}

export interface DeleteAccountData {
  account_delete?: Account_Key | null;
}

export interface DeleteAccountVariables {
  id: UUIDString;
}

export interface DeleteLoanData {
  loan_delete?: Loan_Key | null;
}

export interface DeleteLoanVariables {
  id: UUIDString;
}

export interface DeleteMemberData {
  member_delete?: Member_Key | null;
}

export interface DeleteRepaymentData {
  loanRepayment_delete?: LoanRepayment_Key | null;
}

export interface DeleteRepaymentVariables {
  id: UUIDString;
}

export interface DeleteTransactionData {
  transaction_delete?: Transaction_Key | null;
}

export interface DeleteTransactionVariables {
  id: UUIDString;
}

export interface GetLoanDetailsData {
  loan?: {
    principalAmount: number;
    status: string;
    dueDate: DateString;
  };
}

export interface GetLoanDetailsVariables {
  id: UUIDString;
}

export interface GetMyProfileData {
  member?: {
    fullName: string;
    email: string;
    status: string;
  };
}

export interface ListLoanRepaymentsData {
  loanRepayments: ({
    amountPaid: number;
    paymentDate: TimestampString;
  })[];
}

export interface ListLoanRepaymentsVariables {
  loanId: UUIDString;
}

export interface ListMyAccountsData {
  accounts: ({
    id: UUIDString;
    totalSavings: number;
    outstandingLoans: number;
  } & Account_Key)[];
}

export interface ListMyTransactionsData {
  transactions: ({
    amount: number;
    type: string;
    date: TimestampString;
  })[];
}

export interface LoanRepayment_Key {
  id: UUIDString;
  __typename?: 'LoanRepayment_Key';
}

export interface Loan_Key {
  id: UUIDString;
  __typename?: 'Loan_Key';
}

export interface Member_Key {
  id: UUIDString;
  __typename?: 'Member_Key';
}

export interface RecordTransactionData {
  transaction_insert: Transaction_Key;
}

export interface RecordTransactionVariables {
  amount: number;
  type: string;
}

export interface Transaction_Key {
  id: UUIDString;
  __typename?: 'Transaction_Key';
}

export interface UpdateAccountSavingsData {
  account_update?: Account_Key | null;
}

export interface UpdateAccountSavingsVariables {
  id: UUIDString;
  totalSavings: number;
}

export interface UpdateLoanStatusData {
  loan_update?: Loan_Key | null;
}

export interface UpdateLoanStatusVariables {
  id: UUIDString;
  status: string;
}

export interface UpdateMemberProfileData {
  member_update?: Member_Key | null;
}

export interface UpdateMemberProfileVariables {
  fullName: string;
}

export interface UpdateRepaymentData {
  loanRepayment_update?: LoanRepayment_Key | null;
}

export interface UpdateRepaymentVariables {
  id: UUIDString;
  amount: number;
}

export interface UpdateTransactionNotesData {
  transaction_update?: Transaction_Key | null;
}

export interface UpdateTransactionNotesVariables {
  id: UUIDString;
  notes: string;
}

/** Generated Node Admin SDK operation action function for the 'CreateMemberData' Mutation. Allow users to execute without passing in DataConnect. */
export function createMemberData(dc: DataConnect, vars: CreateMemberDataVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateMemberDataData>>;
/** Generated Node Admin SDK operation action function for the 'CreateMemberData' Mutation. Allow users to pass in custom DataConnect instances. */
export function createMemberData(vars: CreateMemberDataVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateMemberDataData>>;

/** Generated Node Admin SDK operation action function for the 'UpdateMemberProfile' Mutation. Allow users to execute without passing in DataConnect. */
export function updateMemberProfile(dc: DataConnect, vars: UpdateMemberProfileVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateMemberProfileData>>;
/** Generated Node Admin SDK operation action function for the 'UpdateMemberProfile' Mutation. Allow users to pass in custom DataConnect instances. */
export function updateMemberProfile(vars: UpdateMemberProfileVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateMemberProfileData>>;

/** Generated Node Admin SDK operation action function for the 'DeleteMember' Mutation. Allow users to execute without passing in DataConnect. */
export function deleteMember(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteMemberData>>;
/** Generated Node Admin SDK operation action function for the 'DeleteMember' Mutation. Allow users to pass in custom DataConnect instances. */
export function deleteMember(options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteMemberData>>;

/** Generated Node Admin SDK operation action function for the 'GetMyProfile' Query. Allow users to execute without passing in DataConnect. */
export function getMyProfile(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<GetMyProfileData>>;
/** Generated Node Admin SDK operation action function for the 'GetMyProfile' Query. Allow users to pass in custom DataConnect instances. */
export function getMyProfile(options?: OperationOptions): Promise<ExecuteOperationResponse<GetMyProfileData>>;

/** Generated Node Admin SDK operation action function for the 'CreateAccount' Mutation. Allow users to execute without passing in DataConnect. */
export function createAccount(dc: DataConnect, vars: CreateAccountVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateAccountData>>;
/** Generated Node Admin SDK operation action function for the 'CreateAccount' Mutation. Allow users to pass in custom DataConnect instances. */
export function createAccount(vars: CreateAccountVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateAccountData>>;

/** Generated Node Admin SDK operation action function for the 'UpdateAccountSavings' Mutation. Allow users to execute without passing in DataConnect. */
export function updateAccountSavings(dc: DataConnect, vars: UpdateAccountSavingsVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateAccountSavingsData>>;
/** Generated Node Admin SDK operation action function for the 'UpdateAccountSavings' Mutation. Allow users to pass in custom DataConnect instances. */
export function updateAccountSavings(vars: UpdateAccountSavingsVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateAccountSavingsData>>;

/** Generated Node Admin SDK operation action function for the 'DeleteAccount' Mutation. Allow users to execute without passing in DataConnect. */
export function deleteAccount(dc: DataConnect, vars: DeleteAccountVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteAccountData>>;
/** Generated Node Admin SDK operation action function for the 'DeleteAccount' Mutation. Allow users to pass in custom DataConnect instances. */
export function deleteAccount(vars: DeleteAccountVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteAccountData>>;

/** Generated Node Admin SDK operation action function for the 'ListMyAccounts' Query. Allow users to execute without passing in DataConnect. */
export function listMyAccounts(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<ListMyAccountsData>>;
/** Generated Node Admin SDK operation action function for the 'ListMyAccounts' Query. Allow users to pass in custom DataConnect instances. */
export function listMyAccounts(options?: OperationOptions): Promise<ExecuteOperationResponse<ListMyAccountsData>>;

/** Generated Node Admin SDK operation action function for the 'CreateLoan' Mutation. Allow users to execute without passing in DataConnect. */
export function createLoan(dc: DataConnect, vars: CreateLoanVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateLoanData>>;
/** Generated Node Admin SDK operation action function for the 'CreateLoan' Mutation. Allow users to pass in custom DataConnect instances. */
export function createLoan(vars: CreateLoanVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateLoanData>>;

/** Generated Node Admin SDK operation action function for the 'UpdateLoanStatus' Mutation. Allow users to execute without passing in DataConnect. */
export function updateLoanStatus(dc: DataConnect, vars: UpdateLoanStatusVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateLoanStatusData>>;
/** Generated Node Admin SDK operation action function for the 'UpdateLoanStatus' Mutation. Allow users to pass in custom DataConnect instances. */
export function updateLoanStatus(vars: UpdateLoanStatusVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateLoanStatusData>>;

/** Generated Node Admin SDK operation action function for the 'DeleteLoan' Mutation. Allow users to execute without passing in DataConnect. */
export function deleteLoan(dc: DataConnect, vars: DeleteLoanVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteLoanData>>;
/** Generated Node Admin SDK operation action function for the 'DeleteLoan' Mutation. Allow users to pass in custom DataConnect instances. */
export function deleteLoan(vars: DeleteLoanVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteLoanData>>;

/** Generated Node Admin SDK operation action function for the 'GetLoanDetails' Query. Allow users to execute without passing in DataConnect. */
export function getLoanDetails(dc: DataConnect, vars: GetLoanDetailsVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<GetLoanDetailsData>>;
/** Generated Node Admin SDK operation action function for the 'GetLoanDetails' Query. Allow users to pass in custom DataConnect instances. */
export function getLoanDetails(vars: GetLoanDetailsVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<GetLoanDetailsData>>;

/** Generated Node Admin SDK operation action function for the 'AddRepayment' Mutation. Allow users to execute without passing in DataConnect. */
export function addRepayment(dc: DataConnect, vars: AddRepaymentVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<AddRepaymentData>>;
/** Generated Node Admin SDK operation action function for the 'AddRepayment' Mutation. Allow users to pass in custom DataConnect instances. */
export function addRepayment(vars: AddRepaymentVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<AddRepaymentData>>;

/** Generated Node Admin SDK operation action function for the 'UpdateRepayment' Mutation. Allow users to execute without passing in DataConnect. */
export function updateRepayment(dc: DataConnect, vars: UpdateRepaymentVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateRepaymentData>>;
/** Generated Node Admin SDK operation action function for the 'UpdateRepayment' Mutation. Allow users to pass in custom DataConnect instances. */
export function updateRepayment(vars: UpdateRepaymentVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateRepaymentData>>;

/** Generated Node Admin SDK operation action function for the 'DeleteRepayment' Mutation. Allow users to execute without passing in DataConnect. */
export function deleteRepayment(dc: DataConnect, vars: DeleteRepaymentVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteRepaymentData>>;
/** Generated Node Admin SDK operation action function for the 'DeleteRepayment' Mutation. Allow users to pass in custom DataConnect instances. */
export function deleteRepayment(vars: DeleteRepaymentVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteRepaymentData>>;

/** Generated Node Admin SDK operation action function for the 'ListLoanRepayments' Query. Allow users to execute without passing in DataConnect. */
export function listLoanRepayments(dc: DataConnect, vars: ListLoanRepaymentsVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<ListLoanRepaymentsData>>;
/** Generated Node Admin SDK operation action function for the 'ListLoanRepayments' Query. Allow users to pass in custom DataConnect instances. */
export function listLoanRepayments(vars: ListLoanRepaymentsVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<ListLoanRepaymentsData>>;

/** Generated Node Admin SDK operation action function for the 'RecordTransaction' Mutation. Allow users to execute without passing in DataConnect. */
export function recordTransaction(dc: DataConnect, vars: RecordTransactionVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<RecordTransactionData>>;
/** Generated Node Admin SDK operation action function for the 'RecordTransaction' Mutation. Allow users to pass in custom DataConnect instances. */
export function recordTransaction(vars: RecordTransactionVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<RecordTransactionData>>;

/** Generated Node Admin SDK operation action function for the 'UpdateTransactionNotes' Mutation. Allow users to execute without passing in DataConnect. */
export function updateTransactionNotes(dc: DataConnect, vars: UpdateTransactionNotesVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateTransactionNotesData>>;
/** Generated Node Admin SDK operation action function for the 'UpdateTransactionNotes' Mutation. Allow users to pass in custom DataConnect instances. */
export function updateTransactionNotes(vars: UpdateTransactionNotesVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<UpdateTransactionNotesData>>;

/** Generated Node Admin SDK operation action function for the 'DeleteTransaction' Mutation. Allow users to execute without passing in DataConnect. */
export function deleteTransaction(dc: DataConnect, vars: DeleteTransactionVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteTransactionData>>;
/** Generated Node Admin SDK operation action function for the 'DeleteTransaction' Mutation. Allow users to pass in custom DataConnect instances. */
export function deleteTransaction(vars: DeleteTransactionVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<DeleteTransactionData>>;

/** Generated Node Admin SDK operation action function for the 'ListMyTransactions' Query. Allow users to execute without passing in DataConnect. */
export function listMyTransactions(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<ListMyTransactionsData>>;
/** Generated Node Admin SDK operation action function for the 'ListMyTransactions' Query. Allow users to pass in custom DataConnect instances. */
export function listMyTransactions(options?: OperationOptions): Promise<ExecuteOperationResponse<ListMyTransactionsData>>;

