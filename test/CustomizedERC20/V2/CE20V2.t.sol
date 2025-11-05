// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {CE20V2} from "contracts/CustomizedERC20/v2/CE20V2.sol";

// V2 测试：覆盖元数据、转账、授权、permit、事件、fuzz 与差分
contract CE20V2Test is Test {
    // 为事件断言声明与被测合约相同签名的事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    // 常量与账户
    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    uint256 ownerPrivateKey = 0xA11CE; // 仅测试用私钥
    address accountOwner = vm.addr(ownerPrivateKey);
    address accountAlice = address(0xBEEF);
    address accountBob = address(0xCAFE);
    address accountSpender = address(0xD00D);

    CE20V2 tokenUnderTest;

    // 基础环境
    function setUp() public {
        vm.prank(accountOwner);
        tokenUnderTest = new CE20V2("CE20V2", "CE20V2");
    }

    // 1) 元数据：名称 / 符号 / 精度 / 初始总量
    function test_metadata() public {
        // 名称与符号需要比较 bytes 哈希，避免字符串直接比较
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

        // 精度应为 18
        require(tokenUnderTest.decimals() == 18, "decimals mismatch");

        // 初始总量应为 0
        require(tokenUnderTest.totalSupply() == 0, "initial supply not zero");
    }

    // 2) 铸造/转账/销毁
    function test_mint_transfer_burn_skeleton() public {
        // 步骤：
        // - 以 accountOwner 身份给 accountAlice mint 若干代币
        // - 以 accountAlice 身份向 accountBob 转账一部分
        // - 以 accountAlice 身份 burn 一部分
        // - 最终断言 accountAlice/accountBob 余额与 totalSupply 变化
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

    // 3) 转账到零地址应 revert（ZeroAddress）
    function test_transfer_zero_to_reverts_skeleton() public {
        // 步骤：
        // - accountOwner -> accountAlice mint
        // - 预期 revert：vm.expectRevert(CE20V2.ZeroAddress.selector)
        // - 以 accountAlice 身份执行 transfer(address(0), 1)

        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, 10000);
        vm.prank(accountAlice);
        vm.expectRevert(CE20V2.ZeroAddress.selector);
        tokenUnderTest.transfer(address(0), 1);
    }

    // 4) 授权 + transferFrom 扣减额度
    function test_approve_and_transferFrom_skeleton() public {
        // 步骤：
        // - accountOwner -> accountAlice mint
        // - 以 accountAlice 身份 approve(accountSpender, N)
        // - 以 accountSpender 身份 transferFrom(accountAlice, accountBob, x)
        // - 断言 accountBob 余额与 allowance 扣减
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, 10000);
        vm.prank(accountAlice);
        tokenUnderTest.approve(accountSpender, 2);
        vm.prank(accountSpender);
        tokenUnderTest.transferFrom(accountAlice, accountBob, 1);
        require(tokenUnderTest.balanceOf(accountBob) == 1);
        require(tokenUnderTest.allowance(accountAlice, accountSpender) == 1);
    }

    // 5) increase/decreaseAllowance
    function test_increase_decrease_allowance_skeleton() public {
        // 步骤：
        // - 以 accountAlice 身份 approve(accountSpender, a)
        // - increaseAllowance(accountSpender, b)
        // - decreaseAllowance(accountSpender, c)
        // - 断言 allowance(accountAlice, accountSpender) 为 a+b-c
        vm.startPrank(accountAlice);
        tokenUnderTest.approve(accountSpender, 3);
        tokenUnderTest.increaseAllowance(accountSpender, 2);
        tokenUnderTest.decreaseAllowance(accountSpender, 1);
        vm.stopPrank();
        require(tokenUnderTest.allowance(accountAlice, accountSpender) == 4);
    }

    // 6) Permit (EIP-2612)
    function test_permit_skeleton() public {
        // 步骤：
        // - 取 permitOwner = vm.addr(ownerPrivateKey)
        // - 读取 nonce = tokenUnderTest.nonces(permitOwner)
        // - 构造 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, permitOwner, accountSpender, value, nonce, deadline))
        // - 读取域：bytes32 domain = tokenUnderTest.DOMAIN_SEPARATOR()
        // - 拼 digest = keccak256(abi.encodePacked("\x19\x01", domain, structHash))
        // - 用 vm.sign(ownerPrivateKey, digest) 得到 v,r,s
        // - 调用 tokenUnderTest.permit(permitOwner, accountSpender, value, deadline, v, r, s)
        // - 断言 allowance(permitOwner, accountSpender) 与 nonces 增长
        address permitOwner = vm.addr(ownerPrivateKey);
        uint256 nonce = tokenUnderTest.nonces(permitOwner);
        uint256 previousAllowance = tokenUnderTest.allowance(
            permitOwner,
            accountSpender
        );
        uint256 value = 1;
        uint256 deadline = block.timestamp + 100; //设置必定不超时
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
        // 建议步骤：
        // - 以 accountOwner 身份给 accountAlice mint（任意正数）
        //   vm.prank(accountOwner);
        //   tokenUnderTest.mint(accountAlice, 1000);
        // - 以 accountAlice 身份授权 accountSpender 为 type(uint256).max
        //   vm.prank(accountAlice);
        //   tokenUnderTest.approve(accountSpender, type(uint256).max);
        // - 以 accountSpender 身份执行 transferFrom(accountAlice, accountBob, 1)
        //   vm.prank(accountSpender);
        //   tokenUnderTest.transferFrom(accountAlice, accountBob, 1);
        // - 断言：allowance(accountAlice, accountSpender) 仍为 type(uint256).max
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

    // 8) decreaseAllowance 超额减少应当 revert（AllowanceExceeded）
    function test_decreaseAllowance_revertsWhenExceeds_skeleton() public {
        // 标准写法：预期完整的 revert data（含参数）
        vm.startPrank(accountAlice);
        tokenUnderTest.approve(accountSpender, 1);
        uint256 beforeAllowance = tokenUnderTest.allowance(
            accountAlice,
            accountSpender
        );

        // 期望 CE20V2.AllowanceExceeded(uint256 allowance, uint256 needed)
        vm.expectRevert(
            abi.encodeWithSelector(
                CE20V2.AllowanceExceeded.selector,
                beforeAllowance,
                2
            )
        );
        tokenUnderTest.decreaseAllowance(accountSpender, 2);

        // revert 后额度应保持不变
        require(
            tokenUnderTest.allowance(accountAlice, accountSpender) ==
                beforeAllowance,
            "allowance changed"
        );
        vm.stopPrank();
    }

    // 9) onlyOwner：非所有者 mint 应当 revert（NotOwner）
    function test_mint_onlyOwner_revertsForNonOwner_skeleton() public {
        // 建议步骤：
        // - 以 accountAlice 身份调用 mint；
        // - 预期：vm.expectRevert(CE20V2.NotOwner.selector)
        vm.prank(accountAlice);
        vm.expectRevert(CE20V2.NotOwner.selector);
        tokenUnderTest.mint(accountAlice, 2);
    }

    // 10) burnFrom：应减少持有人余额、总量与授权额度
    function test_burnFrom_decreasesSupplyAndAllowance_skeleton() public {
        // 建议步骤：
        // - owner -> alice mint（如 5）
        // - alice approve(spender, 3)
        // - spender 调用 burnFrom(alice, 2)
        // - 断言：alice 余额为 3，总量为 3，allowance(alice, spender) 为 1
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
        // 过期检查先于签名验证，无需构造有效签名
        address owner = accountOwner;
        uint256 value = 1;
        uint256 deadline = block.timestamp - 1;

        // 严格匹配带参错误：PermitExpired(deadline)
        vm.expectRevert(
            abi.encodeWithSelector(CE20V2.PermitExpired.selector, deadline)
        );
        // v/r/s 可为任意值
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
        // 正确 owner = accountOwner，但用错误私钥签名 → 应当 InvalidSignature
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
            abi.encodeWithSelector(CE20V2.InvalidSignature.selector)
        );
        tokenUnderTest.permit(owner, accountSpender, value, deadline, v, r, s);
    }

    // 13) 事件断言（Transfer / Approval）
    function test_events_transfer_and_approval_skeleton() public {
        // 目的：演示 vm.expectEmit 的基本用法；无需 forge-std 亦可使用。
        // 建议步骤：
        // - owner -> alice mint(amount)
        // - 预期下一笔事件为 Transfer(0x0 -> alice, amount)：
        //   vm.expectEmit(true, true, false, true);
        //   emit Transfer(address(0), accountAlice, amount);
        //   tokenUnderTest.mint(accountAlice, amount);
        // - 预期下一笔事件为 Approval(owner, spender, value)：
        //   vm.expectEmit(true, true, false, true);
        //   emit Approval(accountAlice, accountSpender, value);
        //   以 alice 身份调用 approve(spender, value)
        uint256 amount = 200;
        vm.prank(accountOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), accountAlice, amount);
        tokenUnderTest.mint(accountAlice, amount);
    }

    uint256[] public fixtureT14_transferAmount = [0, 1e18, type(uint256).max];
    // 14) Fuzz 测试
    function test_fuzz_transfer_skeleton(uint256 T14_transferAmount) public {
        // 目的：对 transfer 的不同金额做模糊测试（fuzz）。
        // 建议步骤：
        // - 约束 transferAmount 的范围（例如 0 <= amount <= 1e18）：
        //   vm.assume(transferAmount <= 1e18);
        // - owner -> alice mint(transferAmount)
        // - 以 alice 身份 transfer(bob, transferAmount)
        // - 断言：balanceOf(bob) == transferAmount
        // 注意：如果想更严谨，可在引入 forge-std 后使用 bound(amount, min, max) 规约范围。
        vm.prank(accountOwner);
        tokenUnderTest.mint(accountAlice, T14_transferAmount);
        vm.prank(accountAlice);
        tokenUnderTest.transfer(accountBob, T14_transferAmount);
    }

    // 15) 差分测试（与 OpenZeppelin 版本对比）
    function test_diff_against_OZ_skeleton() public {
        // 目的：相同输入下，对比 CE20V2 与 CE20_OPV2 的行为一致性（余额/授权/事件）。
        // 建议步骤：
        // - 部署 CE20_OPV2（OZ 版本），使用相同的 name/symbol/owner
        // - 随机选择若干组输入（mint/transfer/approve/transferFrom/increase/decrease）
        // - 分别在两份合约上执行，并断言状态一致
        // 提示：如需批量输入，可结合 fuzz 与快照/回滚（vm.snapshot/vm.revertTo）
        

    }
}
