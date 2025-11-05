// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {CE20_OPV2} from "contracts/CustomizedERC20/v2/CE20_openzepplinV2.sol";
import {CE20V2} from "contracts/CustomizedERC20/v2/CE20V2.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// 针对 OpenZeppelin 版本（CE20_OPV2）的测试
contract CE20_OPV2Test is Test {
    // 事件声明与被测合约一致
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // EIP-2612
    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    // 账户与常量
    uint256 ownerPrivateKey = 0xA11CE; // 仅用于测试
    address accountOwner = vm.addr(ownerPrivateKey);
    address accountAlice = address(0xBEEF);
    address accountBob = address(0xCAFE);
    address accountSpender = address(0xD00D);

    CE20_OPV2 tokenUnderTest;

    function setUp() public {
        // 部署时直接指定 owner，无需 prank
        tokenUnderTest = new CE20_OPV2("CE20V2", "CE20V2", accountOwner);
    }

    // 1) 元数据：名称 / 符号 / 精度 / 初始总量
    function test_metadata() public {
        string memory nameValue = tokenUnderTest.name();
        string memory symbolValue = tokenUnderTest.symbol();
        require(
            keccak256(bytes(nameValue)) == keccak256(bytes("CE20V2")),
            "name mismatch"
        );
        require(
            keccak256(bytes(symbolValue)) == keccak256(bytes("CE20V2")),
            "symbol mismatch"
        );

        require(tokenUnderTest.decimals() == 18, "decimals mismatch");
        require(tokenUnderTest.totalSupply() == 0, "initial supply not zero");
    }

    // 2) 铸造/转账/销毁（与 CE20V2 顺序一致）
    function test_mint_transfer_burn_skeleton() public {
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, 10000);

        vm.startPrank(accountAlice);
        tokenUnderTest.transfer(accountBob, 1);
        tokenUnderTest.burn(1);
        vm.stopPrank();

        require(tokenUnderTest.balanceOf(accountAlice) == 9998);
        require(tokenUnderTest.balanceOf(accountBob) == 1);
        require(tokenUnderTest.totalSupply() == 9999);
    }

    // 3) 转账到零地址应 revert（OZ v5: ERC20InvalidReceiver(address(0)）
    function test_transfer_zero_to_reverts_skeleton() public {
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, 10000);

        vm.prank(accountAlice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        tokenUnderTest.transfer(address(0), 1);
    }

    // 4) 授权 + transferFrom 扣减额度
    function test_approve_and_transferFrom_skeleton() public {
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, 10000);

        vm.prank(accountAlice);
        tokenUnderTest.approve(accountSpender, 2);

        vm.prank(accountSpender);
        tokenUnderTest.transferFrom(accountAlice, accountBob, 1);

        require(tokenUnderTest.balanceOf(accountBob) == 1);
        require(tokenUnderTest.allowance(accountAlice, accountSpender) == 1);
    }

    // 5) increase/decreaseAllowance（OZ v5 无该接口，使用 approve 复现语义）
    function test_increase_decrease_allowance_skeleton() public {
        vm.startPrank(accountAlice);
        tokenUnderTest.approve(accountSpender, 3);
        uint256 cur = tokenUnderTest.allowance(accountAlice, accountSpender);
        tokenUnderTest.approve(accountSpender, cur + 2); // increase -> 5
        cur = tokenUnderTest.allowance(accountAlice, accountSpender);
        tokenUnderTest.approve(accountSpender, cur - 1); // decrease -> 4
        vm.stopPrank();
        require(tokenUnderTest.allowance(accountAlice, accountSpender) == 4);
    }

    // 6) Permit (EIP-2612)
    function test_permit_skeleton() public {
        address permitOwner = accountOwner;
        uint256 nonce = tokenUnderTest.nonces(permitOwner);
        uint256 previousAllowance = tokenUnderTest.allowance(
            permitOwner,
            accountSpender
        );
        uint256 value = 1;
        uint256 deadline = block.timestamp + 100; // not expired
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                permitOwner,
                accountSpender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 domain = tokenUnderTest.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domain, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        tokenUnderTest.permit(
            permitOwner,
            accountSpender,
            value,
            deadline,
            v,
            r,
            s
        );
        require(previousAllowance == 0);
        require(tokenUnderTest.allowance(permitOwner, accountSpender) == value);
        require(tokenUnderTest.nonces(permitOwner) == nonce + 1);
    }

    // 7) 无限授权（uint256.max）：transferFrom 后 allowance 不应减少
    function test_infiniteAllowance_transferFrom_doesNotDecrease_skeleton()
        public
    {
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, 1000);
        vm.prank(accountAlice);
        tokenUnderTest.approve(accountSpender, type(uint256).max);
        vm.prank(accountSpender);
        tokenUnderTest.transferFrom(accountAlice, accountBob, 1);
        require(
            tokenUnderTest.allowance(accountAlice, accountSpender) ==
                type(uint256).max
        );
    }

    // 8) decreaseAllowance 超额减少应当 revert（OZ 适配：花费超额应当 revert ERC20InsufficientAllowance）
    function test_decreaseAllowance_revertsWhenExceeds_skeleton() public {
        vm.startPrank(accountAlice);
        tokenUnderTest.approve(accountSpender, 1);
        vm.stopPrank();

        vm.prank(accountSpender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                accountSpender,
                1,
                2
            )
        );
        tokenUnderTest.transferFrom(accountAlice, accountBob, 2);
    }

    // 9) onlyOwner：非所有者 mint 应当 revert（Ownable）
    function test_mint_onlyOwner_revertsForNonOwner_skeleton() public {
        vm.prank(accountAlice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                accountAlice
            )
        );
        tokenUnderTest.mint(accountAlice, 2);
    }

    // 10) burnFrom：应减少持有人余额、总量与授权额度
    function test_burnFrom_decreasesSupplyAndAllowance_skeleton() public {
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, 5);

        vm.prank(accountAlice);
        tokenUnderTest.approve(accountSpender, 3);

        vm.prank(accountSpender);
        tokenUnderTest.burnFrom(accountAlice, 2);

        require(tokenUnderTest.balanceOf(accountAlice) == 3);
        require(tokenUnderTest.totalSupply() == 3);
        require(tokenUnderTest.allowance(accountAlice, accountSpender) == 1);
    }

    // 11) permit 过期应当 revert（PermitExpired）
    function test_permit_expired_reverts_skeleton() public {
        address owner = accountOwner;
        uint256 value = 1;
        uint256 deadline = block.timestamp - 1;

        vm.expectRevert(
            abi.encodeWithSelector(CE20_OPV2.PermitExpired.selector, deadline)
        );
        tokenUnderTest.permit(
            owner,
            accountSpender,
            value,
            deadline,
            27,
            bytes32(0),
            bytes32(0)
        );
    }

    // 12) permit 使用错误签名者应当 revert（InvalidSignature）
    function test_permit_wrongSigner_reverts_skeleton() public {
        address owner = accountOwner;
        uint256 value = 1;
        uint256 nonce = tokenUnderTest.nonces(owner);
        uint256 deadline = block.timestamp + 100;

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                accountSpender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 domain = tokenUnderTest.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domain, structHash)
        );

        uint256 wrongPrivateKey = uint256(0xBEEF);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);

        vm.expectRevert(
            abi.encodeWithSelector(CE20_OPV2.InvalidSignature.selector)
        );
        tokenUnderTest.permit(owner, accountSpender, value, deadline, v, r, s);
    }

    
    // 13) 事件断言（Transfer / Approval）
    function test_events_transfer_and_approval_skeleton() public {
        uint256 amount = 200;
        vm.prank(accountOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), accountAlice, amount);
        tokenUnderTest.mint(accountAlice, amount);

        vm.prank(accountAlice);
        vm.expectEmit(true, true, false, true);
        emit Approval(accountAlice, accountSpender, 7);
        tokenUnderTest.approve(accountSpender, 7);
    }

    uint256[] public fixtureT14_transferAmount = [0, 1e18, type(uint256).max];
    // 14) Fuzz 测试
    function test_fuzz_transfer_skeleton(uint256 T14_transferAmount) public {
        vm.assume(T14_transferAmount <= 1e18);
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, T14_transferAmount);
        vm.prank(accountAlice);
        tokenUnderTest.transfer(accountBob, T14_transferAmount);
        require(tokenUnderTest.balanceOf(accountBob) == T14_transferAmount);
    }

    // 15) 差分测试（与 CE20V2 对比）
    function test_diff_against_OZ_skeleton() public {
        CE20_OPV2 op = new CE20_OPV2("CE20V2", "CE20V2", accountOwner);
        vm.prank(accountOwner);
        CE20V2 v2 = new CE20V2("CE20V2", "CE20V2");

        vm.prank(accountOwner);
        op.mint(accountAlice, 100);
        vm.prank(accountOwner);
        v2.mint(accountAlice, 100);

        vm.prank(accountAlice);
        op.approve(accountSpender, 10);
        vm.prank(accountAlice);
        v2.approve(accountSpender, 10);

        vm.prank(accountSpender);
        op.transferFrom(accountAlice, accountBob, 3);
        vm.prank(accountSpender);
        v2.transferFrom(accountAlice, accountBob, 3);

        require(op.totalSupply() == v2.totalSupply(), "supply mismatch");
        require(
            op.balanceOf(accountAlice) == v2.balanceOf(accountAlice),
            "alice balance mismatch"
        );
        require(
            op.balanceOf(accountBob) == v2.balanceOf(accountBob),
            "bob balance mismatch"
        );
        require(
            op.allowance(accountAlice, accountSpender) ==
                v2.allowance(accountAlice, accountSpender),
            "allowance mismatch"
        );
    }
}
