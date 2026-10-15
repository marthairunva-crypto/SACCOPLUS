import { ConnectorConfig, DataConnect, QueryRef, QueryPromise, ExecuteQueryOptions, MutationRef, MutationPromise, DataConnectSettings } from 'firebase/data-connect';

export const connectorConfig: ConnectorConfig;
export const dataConnectSettings: DataConnectSettings;

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

interface CreateMemberDataRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateMemberDataVariables): MutationRef<CreateMemberDataData, CreateMemberDataVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreateMemberDataVariables): MutationRef<CreateMemberDataData, CreateMemberDataVariables>;
  operationName: string;
}
export const createMemberDataRef: CreateMemberDataRef;

export function createMemberData(vars: CreateMemberDataVariables): MutationPromise<CreateMemberDataData, CreateMemberDataVariables>;
export function createMemberData(dc: DataConnect, vars: CreateMemberDataVariables): MutationPromise<CreateMemberDataData, CreateMemberDataVariables>;

interface UpdateMemberProfileRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateMemberProfileVariables): MutationRef<UpdateMemberProfileData, UpdateMemberProfileVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateMemberProfileVariables): MutationRef<UpdateMemberProfileData, UpdateMemberProfileVariables>;
  operationName: string;
}
export const updateMemberProfileRef: UpdateMemberProfileRef;

export function updateMemberProfile(vars: UpdateMemberProfileVariables): MutationPromise<UpdateMemberProfileData, UpdateMemberProfileVariables>;
export function updateMemberProfile(dc: DataConnect, vars: UpdateMemberProfileVariables): MutationPromise<UpdateMemberProfileData, UpdateMemberProfileVariables>;

interface DeleteMemberRef {
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<DeleteMemberData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): MutationRef<DeleteMemberData, undefined>;
  operationName: string;
}
export const deleteMemberRef: DeleteMemberRef;

export function deleteMember(): MutationPromise<DeleteMemberData, undefined>;
export function deleteMember(dc: DataConnect): MutationPromise<DeleteMemberData, undefined>;

interface GetMyProfileRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<GetMyProfileData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<GetMyProfileData, undefined>;
  operationName: string;
}
export const getMyProfileRef: GetMyProfileRef;

export function getMyProfile(options?: ExecuteQueryOptions): QueryPromise<GetMyProfileData, undefined>;
export function getMyProfile(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<GetMyProfileData, undefined>;

interface CreateAccountRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateAccountVariables): MutationRef<CreateAccountData, CreateAccountVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreateAccountVariables): MutationRef<CreateAccountData, CreateAccountVariables>;
  operationName: string;
}
export const createAccountRef: CreateAccountRef;

export function createAccount(vars: CreateAccountVariables): MutationPromise<CreateAccountData, CreateAccountVariables>;
export function createAccount(dc: DataConnect, vars: CreateAccountVariables): MutationPromise<CreateAccountData, CreateAccountVariables>;

interface UpdateAccountSavingsRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateAccountSavingsVariables): MutationRef<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateAccountSavingsVariables): MutationRef<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;
  operationName: string;
}
export const updateAccountSavingsRef: UpdateAccountSavingsRef;

export function updateAccountSavings(vars: UpdateAccountSavingsVariables): MutationPromise<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;
export function updateAccountSavings(dc: DataConnect, vars: UpdateAccountSavingsVariables): MutationPromise<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;

interface DeleteAccountRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteAccountVariables): MutationRef<DeleteAccountData, DeleteAccountVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeleteAccountVariables): MutationRef<DeleteAccountData, DeleteAccountVariables>;
  operationName: string;
}
export const deleteAccountRef: DeleteAccountRef;

export function deleteAccount(vars: DeleteAccountVariables): MutationPromise<DeleteAccountData, DeleteAccountVariables>;
export function deleteAccount(dc: DataConnect, vars: DeleteAccountVariables): MutationPromise<DeleteAccountData, DeleteAccountVariables>;

interface ListMyAccountsRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListMyAccountsData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<ListMyAccountsData, undefined>;
  operationName: string;
}
export const listMyAccountsRef: ListMyAccountsRef;

export function listMyAccounts(options?: ExecuteQueryOptions): QueryPromise<ListMyAccountsData, undefined>;
export function listMyAccounts(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListMyAccountsData, undefined>;

interface CreateLoanRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateLoanVariables): MutationRef<CreateLoanData, CreateLoanVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreateLoanVariables): MutationRef<CreateLoanData, CreateLoanVariables>;
  operationName: string;
}
export const createLoanRef: CreateLoanRef;

export function createLoan(vars: CreateLoanVariables): MutationPromise<CreateLoanData, CreateLoanVariables>;
export function createLoan(dc: DataConnect, vars: CreateLoanVariables): MutationPromise<CreateLoanData, CreateLoanVariables>;

interface UpdateLoanStatusRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateLoanStatusVariables): MutationRef<UpdateLoanStatusData, UpdateLoanStatusVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateLoanStatusVariables): MutationRef<UpdateLoanStatusData, UpdateLoanStatusVariables>;
  operationName: string;
}
export const updateLoanStatusRef: UpdateLoanStatusRef;

export function updateLoanStatus(vars: UpdateLoanStatusVariables): MutationPromise<UpdateLoanStatusData, UpdateLoanStatusVariables>;
export function updateLoanStatus(dc: DataConnect, vars: UpdateLoanStatusVariables): MutationPromise<UpdateLoanStatusData, UpdateLoanStatusVariables>;

interface DeleteLoanRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteLoanVariables): MutationRef<DeleteLoanData, DeleteLoanVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeleteLoanVariables): MutationRef<DeleteLoanData, DeleteLoanVariables>;
  operationName: string;
}
export const deleteLoanRef: DeleteLoanRef;

export function deleteLoan(vars: DeleteLoanVariables): MutationPromise<DeleteLoanData, DeleteLoanVariables>;
export function deleteLoan(dc: DataConnect, vars: DeleteLoanVariables): MutationPromise<DeleteLoanData, DeleteLoanVariables>;

interface GetLoanDetailsRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetLoanDetailsVariables): QueryRef<GetLoanDetailsData, GetLoanDetailsVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: GetLoanDetailsVariables): QueryRef<GetLoanDetailsData, GetLoanDetailsVariables>;
  operationName: string;
}
export const getLoanDetailsRef: GetLoanDetailsRef;

export function getLoanDetails(vars: GetLoanDetailsVariables, options?: ExecuteQueryOptions): QueryPromise<GetLoanDetailsData, GetLoanDetailsVariables>;
export function getLoanDetails(dc: DataConnect, vars: GetLoanDetailsVariables, options?: ExecuteQueryOptions): QueryPromise<GetLoanDetailsData, GetLoanDetailsVariables>;

interface AddRepaymentRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: AddRepaymentVariables): MutationRef<AddRepaymentData, AddRepaymentVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: AddRepaymentVariables): MutationRef<AddRepaymentData, AddRepaymentVariables>;
  operationName: string;
}
export const addRepaymentRef: AddRepaymentRef;

export function addRepayment(vars: AddRepaymentVariables): MutationPromise<AddRepaymentData, AddRepaymentVariables>;
export function addRepayment(dc: DataConnect, vars: AddRepaymentVariables): MutationPromise<AddRepaymentData, AddRepaymentVariables>;

interface UpdateRepaymentRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateRepaymentVariables): MutationRef<UpdateRepaymentData, UpdateRepaymentVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateRepaymentVariables): MutationRef<UpdateRepaymentData, UpdateRepaymentVariables>;
  operationName: string;
}
export const updateRepaymentRef: UpdateRepaymentRef;

export function updateRepayment(vars: UpdateRepaymentVariables): MutationPromise<UpdateRepaymentData, UpdateRepaymentVariables>;
export function updateRepayment(dc: DataConnect, vars: UpdateRepaymentVariables): MutationPromise<UpdateRepaymentData, UpdateRepaymentVariables>;

interface DeleteRepaymentRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteRepaymentVariables): MutationRef<DeleteRepaymentData, DeleteRepaymentVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeleteRepaymentVariables): MutationRef<DeleteRepaymentData, DeleteRepaymentVariables>;
  operationName: string;
}
export const deleteRepaymentRef: DeleteRepaymentRef;

export function deleteRepayment(vars: DeleteRepaymentVariables): MutationPromise<DeleteRepaymentData, DeleteRepaymentVariables>;
export function deleteRepayment(dc: DataConnect, vars: DeleteRepaymentVariables): MutationPromise<DeleteRepaymentData, DeleteRepaymentVariables>;

interface ListLoanRepaymentsRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: ListLoanRepaymentsVariables): QueryRef<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: ListLoanRepaymentsVariables): QueryRef<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;
  operationName: string;
}
export const listLoanRepaymentsRef: ListLoanRepaymentsRef;

export function listLoanRepayments(vars: ListLoanRepaymentsVariables, options?: ExecuteQueryOptions): QueryPromise<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;
export function listLoanRepayments(dc: DataConnect, vars: ListLoanRepaymentsVariables, options?: ExecuteQueryOptions): QueryPromise<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;

interface RecordTransactionRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: RecordTransactionVariables): MutationRef<RecordTransactionData, RecordTransactionVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: RecordTransactionVariables): MutationRef<RecordTransactionData, RecordTransactionVariables>;
  operationName: string;
}
export const recordTransactionRef: RecordTransactionRef;

export function recordTransaction(vars: RecordTransactionVariables): MutationPromise<RecordTransactionData, RecordTransactionVariables>;
export function recordTransaction(dc: DataConnect, vars: RecordTransactionVariables): MutationPromise<RecordTransactionData, RecordTransactionVariables>;

interface UpdateTransactionNotesRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateTransactionNotesVariables): MutationRef<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateTransactionNotesVariables): MutationRef<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;
  operationName: string;
}
export const updateTransactionNotesRef: UpdateTransactionNotesRef;

export function updateTransactionNotes(vars: UpdateTransactionNotesVariables): MutationPromise<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;
export function updateTransactionNotes(dc: DataConnect, vars: UpdateTransactionNotesVariables): MutationPromise<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;

interface DeleteTransactionRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteTransactionVariables): MutationRef<DeleteTransactionData, DeleteTransactionVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeleteTransactionVariables): MutationRef<DeleteTransactionData, DeleteTransactionVariables>;
  operationName: string;
}
export const deleteTransactionRef: DeleteTransactionRef;

export function deleteTransaction(vars: DeleteTransactionVariables): MutationPromise<DeleteTransactionData, DeleteTransactionVariables>;
export function deleteTransaction(dc: DataConnect, vars: DeleteTransactionVariables): MutationPromise<DeleteTransactionData, DeleteTransactionVariables>;

interface ListMyTransactionsRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListMyTransactionsData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<ListMyTransactionsData, undefined>;
  operationName: string;
}
export const listMyTransactionsRef: ListMyTransactionsRef;

export function listMyTransactions(options?: ExecuteQueryOptions): QueryPromise<ListMyTransactionsData, undefined>;
export function listMyTransactions(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListMyTransactionsData, undefined>;

