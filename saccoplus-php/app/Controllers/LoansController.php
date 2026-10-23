<?php

namespace App\Controllers;

use App\Core\View;
use App\Core\Auth;
use App\Core\Csrf;
use App\Core\Context;
use App\Core\DB;
use App\Services\LoanService;
use App\Models\Member;
use Exception;

class LoansController
{
    private $loanService;
    
    public function __construct()
    {
        $this->loanService = new LoanService();
    }
    
    /**
     * List all loans
     */
    public function index()
    {
        Auth::require();
        $saccoId = Context::requireSacco();
        
        $filters = [
            'status' => $_GET['status'] ?? '',
            'search' => $_GET['search'] ?? ''
        ];
        
        $where = ['l.sacco_id = ?'];
        $params = [$saccoId];
        
        if ($filters['status']) {
            $where[] = 'l.status = ?';
            $params[] = $filters['status'];
        }
        
        if ($filters['search']) {
            $where[] = '(l.loan_no LIKE ? OR m.full_name LIKE ?)';
            $search = '%' . $filters['search'] . '%';
            $params[] = $search;
            $params[] = $search;
        }
        
        $whereClause = implode(' AND ', $where);
        
        $sql = "
            SELECT l.*, m.full_name as member_name, m.member_no,
                   -- Get outstanding balances from schedule
                   COALESCE((
                       SELECT SUM(principal_due - principal_paid + interest_due - interest_paid + penalty_accrued - penalty_paid)
                       FROM loan_schedule WHERE loan_id = l.id
                   ), 0) as total_balance
            FROM loans l
            INNER JOIN members m ON l.member_id = m.id
            WHERE {$whereClause}
            ORDER BY l.created_at DESC
        ";
        
        $loans = DB::query($sql, $params);
        
        View::render('loans/index', [
            'loans' => $loans,
            'filters' => $filters
        ]);
    }
    
    /**
     * Show loan application form
     */
    public function create()
    {
        Auth::require();
        $saccoId = Context::requireSacco();
        
        $memberId = $_GET['member_id'] ?? null;
        $member = null;
        
        if ($memberId) {
            $member = Member::getById($memberId, $saccoId);
        }
        
        // Get loan products
        $products = DB::query(
            "SELECT * FROM loan_products WHERE sacco_id = ? AND status = 'active' ORDER BY name",
            [$saccoId]
        );
        
        View::render('loans/create', [
            'member' => $member,
            'products' => $products,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Store new loan application
     */
    public function store()
    {
        Auth::require();
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = $this->loanService->applyForLoan([
                'member_id' => (int)$_POST['member_id'],
                'product_id' => (int)$_POST['product_id'],
                'principal' => (float)$_POST['principal'],
                'term_months' => (int)$_POST['term_months'],
                'interest_rate' => (float)$_POST['interest_rate'],
                'interest_method' => $_POST['interest_method'] ?? 'reducing',
                'purpose' => $_POST['purpose'] ?? null,
            ], Auth::user()['id']);
            
            $_SESSION['success'] = "Loan application submitted successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            $_SESSION['old'] = $_POST;
            redirect('/loans/create' . (isset($_POST['member_id']) ? '?member_id=' . $_POST['member_id'] : ''));
        }
    }
    
    /**
     * View loan details
     */
    public function view()
    {
        Auth::require();
        $saccoId = Context::requireSacco();
        
        $loanId = $_GET['id'] ?? null;
        if (!$loanId) {
            $_SESSION['error'] = "Loan ID required";
            redirect('/loans');
            return;
        }
        
        // Get loan with member info
        $sql = "
            SELECT l.*, m.full_name as member_name, m.member_no, m.phone,
                   p.name as product_name,
                   approver.name as approved_by_name
            FROM loans l
            INNER JOIN members m ON l.member_id = m.id
            INNER JOIN loan_products p ON l.product_id = p.id
            LEFT JOIN users approver ON l.approved_by = approver.id
            WHERE l.id = ? AND l.sacco_id = ?
        ";
        
        $loan = DB::query($sql, [$loanId, $saccoId])[0] ?? null;
        
        if (!$loan) {
            $_SESSION['error'] = "Loan not found";
            redirect('/loans');
            return;
        }
        
        $tab = $_GET['tab'] ?? 'summary';
        
        // Get schedule
        $schedule = [];
        if ($loan['status'] === 'active' || $loan['status'] === 'cleared') {
            $schedule = DB::query(
                "SELECT * FROM loan_schedule WHERE loan_id = ? ORDER BY installment_no",
                [$loanId]
            );
        }
        
        // Get repayment history
        $repayments = DB::query(
            "SELECT lr.*, u.name as posted_by_name
             FROM loan_repayments lr
             LEFT JOIN journal_entries je ON lr.journal_entry_id = je.id
             LEFT JOIN users u ON je.posted_by = u.id
             WHERE lr.loan_id = ?
             ORDER BY lr.paid_on DESC",
            [$loanId]
        );
        
        // Calculate outstanding from schedule
        $outstanding = DB::query(
            "SELECT 
                SUM(principal_due - principal_paid) as principal,
                SUM(interest_due - interest_paid) as interest,
                SUM(penalty_accrued - penalty_paid) as penalty
             FROM loan_schedule WHERE loan_id = ?",
            [$loanId]
        )[0] ?? [];
        
        View::render('loans/view', [
            'loan' => $loan,
            'tab' => $tab,
            'schedule' => $schedule,
            'repayments' => $repayments,
            'outstanding' => $outstanding,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Approve loan
     */
    public function approve()
    {
        Auth::require();
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = (int)($_POST['loan_id'] ?? 0);
            $notes = $_POST['notes'] ?? '';
            
            if (!$loanId) {
                throw new Exception("Loan ID required");
            }
            
            $this->loanService->approveLoan($loanId, $notes, Auth::user()['id']);
            
            $_SESSION['success'] = "Loan approved successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/loans/view?id=' . ($_POST['loan_id'] ?? ''));
        }
    }
    
    /**
     * Disburse loan
     */
    public function disburse()
    {
        Auth::require();
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = (int)($_POST['loan_id'] ?? 0);
            $disbursementDate = $_POST['disbursement_date'] ?? date('Y-m-d');
            
            if (!$loanId) {
                throw new Exception("Loan ID required");
            }
            
            $this->loanService->disburseLoan($loanId, $disbursementDate, Auth::user()['id']);
            
            $_SESSION['success'] = "Loan disbursed successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/loans/view?id=' . ($_POST['loan_id'] ?? ''));
        }
    }
    
    /**
     * Show repayment form
     */
    public function repayForm()
    {
        Auth::require();
        $saccoId = Context::requireSacco();
        
        $loanId = $_GET['loan_id'] ?? null;
        if (!$loanId) {
            $_SESSION['error'] = "Loan ID required";
            redirect('/loans');
            return;
        }
        
        // Get loan
        $sql = "
            SELECT l.*, m.full_name as member_name, m.member_no,
                   -- Get member savings balance
                   COALESCE((
                       SELECT SUM(jl.credit - jl.debit)
                       FROM journal_lines jl
                       INNER JOIN member_accounts ma ON jl.member_account_id = ma.id
                       WHERE ma.member_id = l.member_id AND ma.type = 'savings'
                   ), 0) as member_balance
            FROM loans l
            INNER JOIN members m ON l.member_id = m.id
            WHERE l.id = ? AND l.sacco_id = ?
        ";
        
        $loan = DB::query($sql, [$loanId, $saccoId])[0] ?? null;
        
        if (!$loan) {
            $_SESSION['error'] = "Loan not found";
            redirect('/loans');
            return;
        }
        
        // Get outstanding
        $outstanding = DB::query(
            "SELECT 
                SUM(principal_due - principal_paid) as principal,
                SUM(interest_due - interest_paid) as interest,
                SUM(penalty_accrued - penalty_paid) as penalty
             FROM loan_schedule WHERE loan_id = ?",
            [$loanId]
        )[0] ?? [];
        
        View::render('loans/repay', [
            'loan' => $loan,
            'outstanding' => $outstanding,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Record loan repayment
     */
    public function repay()
    {
        Auth::require();
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = (int)($_POST['loan_id'] ?? 0);
            $amount = (float)($_POST['amount'] ?? 0);
            $paymentDate = $_POST['payment_date'] ?? date('Y-m-d');
            $notes = $_POST['notes'] ?? '';
            
            if (!$loanId || $amount <= 0) {
                throw new Exception("Invalid loan or amount");
            }
            
            $this->loanService->recordRepayment(
                $loanId,
                $amount,
                $paymentDate,
                $notes,
                Auth::user()['id']
            );
            
            $_SESSION['success'] = "Payment recorded successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            $_SESSION['old'] = $_POST;
            redirect('/loans/repay?loan_id=' . ($_POST['loan_id'] ?? ''));
        }
    }
}
