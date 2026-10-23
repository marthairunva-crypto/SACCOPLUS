<?php

namespace App\Controllers;

use App\Core\View;
use App\Core\Auth;
use App\Core\Context;
use App\Models\Member;
use App\Services\MemberService;

class MembersController
{
    private $memberService;
    
    public function __construct()
    {
        $this->memberService = new MemberService();
    }
    
    /**
     * List all members
     */
    public function index()
    {
        Auth::require();
        $saccoId = Context::requireSacco();
        
        $filters = [
            'status' => $_GET['status'] ?? '',
            'branch_id' => $_GET['branch_id'] ?? '',
            'search' => $_GET['search'] ?? ''
        ];
        
        $members = Member::getAll($saccoId, $filters);
        
        View::render('members/index', [
            'members' => $members,
            'filters' => $filters
        ]);
    }
    
    /**
     * View member details (Member 360)
     */
    public function view()
    {
        Auth::require();
        
        $memberId = $_GET['id'] ?? null;
        if (!$memberId) {
            $_SESSION['error'] = "Member ID required";
            redirect('/members');
            return;
        }
        
        try {
            $summary = $this->memberService->getMemberSummary($memberId);
            
            View::render('members/view', $summary);
            
        } catch (\Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/members');
        }
    }
    
    /**
     * Search members (AJAX)
     */
    public function search()
    {
        Auth::require();
        $saccoId = Context::requireSacco();
        
        $query = $_GET['q'] ?? '';
        
        if (strlen($query) < 2) {
            header('Content-Type: application/json');
            echo json_encode(['members' => []]);
            return;
        }
        
        $members = Member::search($saccoId, $query);
        
        header('Content-Type: application/json');
        echo json_encode(['members' => $members]);
    }
}
