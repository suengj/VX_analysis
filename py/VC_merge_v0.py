# Suengjae Hong
# VC round data merge
# R 코드를 파이썬으로 변환

import os
import glob
import pandas as pd
import pickle

# 작업 디렉토리 설정

VC_raw_path = "/Users/suengj/Documents/Code/Python/Research/VC/raw"
round_path = os.path.join(VC_raw_path, "round")
round_path_US = os.path.join(round_path, "US")
round_path_Non_US = os.path.join(round_path, "Non_US")

VC_path = os.path.join(VC_raw_path, "firm") # VC
startup_path = os.path.join(VC_raw_path, "comp") # company
perf_path = os.path.join(VC_raw_path, "perf") # IPO, M&A

extract_path = os.path.join(VC_raw_path, "extract") # saved path

round_column_mapping = {
    'Round Date': 'rounddate',
    'Company Name': 'compnm',
    'Company Stage Level 1 at each Round Date': 'comstage1',
    'Company Stage Level 2 at each Round Date': 'comstage2',
    'Company Stage Level 3 at each Round Date': 'comstage3',
    'Standard US Venture Buyout': 'buyout',
    'Deal Number': 'dealno',
    'Disclose Company Valuation': 'valuation',
    'Disclosed Post-Round Company Val. ($000)': 'postValue',
    'Firm Name': 'firmnm',
    'Fund Name': 'fundnm',
    'Round Amount Disclosed ($ Thou)': 'amt_dis',
    'Round Amount Estimated ($ Thou)': 'amt_est',
    'Round Number': 'roundno',
    'Round Number of Investors': 'investorNum',
    'Standard US Venture Disbursement': 'disbursement'
}

company_column_mapping = {
    'Company IPO Date': 'date_ipo',
    'Company Founding Date': 'date_fnd', 
    'Company Current Situation Date': 'date_sit',
    'Company 6-digit CUSIP': 'comcusip',
    'Company Current Situation': 'comsitu',
    'Company Current Public Status': 'compubstat',
    'Company IPO Status': 'comipo',
    'Company MSA Code': 'commsa',
    'Company Name': 'comname',
    'Company Nation Code': 'comnation',
    'Company State Code': 'comstacode',
    'Company Stock Exchange, if Applic.': 'comstock',
    'Company Ticker, if Applic.': 'comticker',
    'Company Industry Class': 'comind',
    'Company Industry Major Group': 'comindmjr',
    'Company Industry Minor Group': 'comindmnr',
    'Company Industry Sub-Group 1': 'comindsub1',
    'Company Industry Sub-Group 2': 'comindsub2',
    'Company Industry Sub-Group 3': 'comindsub3',
    'Company Zip Code': 'comzip'
}

firm_column_mapping = {
    'Firm Name': 'firmnm',
    'Firm Founding Date': 'firmfnd',
    'Firm Nation Code': 'firmnation',
    'Firm State Code': 'firmstate',
    'Firm Zip Code': 'firmzip',
    'Firm Type': 'firmtype',
    'Firm Investment Status': 'firminvstat',
    'Firm MSA Code': 'firmmsa'
}

def read_merge_save_pickle(
    file_path, 
    file_pattern='*.xlsx', 
    column_mapping=None,
    skiprows=None, 
    header=0, 
    output_filename='merged_data.pkl',
    output_path=extract_path,
    verbose=True
):
    """
    Excel 파일들을 병합하고 데이터를 정리하는 함수
    - Disb. ID 컬럼 제거
    - 컬럼명의 \n 제거
    """

    # 디렉토리 존재 확인
    if not os.path.exists(file_path):
        print(f"오류: 경로가 존재하지 않습니다: {file_path}")
        return None

    # 작업 디렉토리 변경
    original_dir = os.getcwd()
    os.chdir(file_path)

    try:
        # 파일 목록 가져오기
        flist = glob.glob(file_pattern)

        if verbose:
            print(f"경로: {file_path}")
            print(f"파일 패턴: {file_pattern}")
            print(f"발견된 파일 수: {len(flist)}")

        if len(flist) == 0:
            print(f"오류: 패턴 '{file_pattern}'에 맞는 파일이 없습니다.")
            return None

        # 데이터 리스트 초기화
        dta_list = []
        success_count = 0
        error_count = 0

        # 각 파일 읽기 (첫 번째 시트만)
        for f_nm in flist:
            try:
                df = pd.read_excel(f_nm, 
                                  sheet_name=0,  # 첫 번째 시트 고정
                                  skiprows=skiprows,
                                  header=header,
                                  dtype=str) 
                dta_list.append(df)
                success_count += 1

                if verbose:
                    print(f"✓ 성공: {f_nm} (크기: {df.shape})")

            except Exception as e:
                error_count += 1
                if verbose:
                    print(f"✗ 오류 ({f_nm}): {e}")

        # 데이터 병합
        if dta_list:
            merged_df = pd.concat(dta_list, ignore_index=True)

            if verbose:
                print(f"\n=== 병합 완료 ===")
                print(f"성공한 파일: {success_count}개")
                print(f"실패한 파일: {error_count}개")
                print(f"병합 후 데이터 크기: {merged_df.shape}")
                print(f"원본 컬럼: {list(merged_df.columns)}")

            # 데이터 정리
            # 1. Disb. ID 컬럼 제거 (있는 경우에만)
            if 'Disb. ID' in merged_df.columns:
                merged_df = merged_df.drop(columns=['Disb. ID'])
                if verbose:
                    print(f"✓ 'Disb. ID' 컬럼 제거됨")

            # 2. 컬럼명의 \n 제거
            original_columns = merged_df.columns.tolist()
            new_columns = [col.replace('\n', ' ') for col in original_columns]
            merged_df.columns = new_columns

            if verbose:
                print(f"✓ 컬럼명의 \\n 제거됨")
                print(f"정리 후 컬럼: {list(merged_df.columns)}")
                print(f"최종 데이터 크기: {merged_df.shape}")

            # 3. 컬럼명 변경
            if column_mapping is not None:
                merged_df = merged_df.rename(columns=column_mapping)

            # 저장 경로 결정
            save_dir = output_path if output_path is not None else file_path
            if not os.path.exists(save_dir):
                os.makedirs(save_dir, exist_ok=True)
            output_full_path = os.path.join(save_dir, output_filename)
            with open(output_full_path, 'wb') as f:
                pickle.dump(merged_df, f)

            if verbose:
                print(f"pickle 파일 저장 완료: {output_full_path}")

            return merged_df

        else:
            print("오류: 읽을 수 있는 파일이 없습니다.")
            return None

    except Exception as e:
        print(f"오류 발생: {e}")
        return None

    finally:
        # 원래 디렉토리로 복원
        os.chdir(original_dir)

def load_pickle_data(file_path):    
    try:
        with open(file_path, 'rb') as f:
            data = pickle.load(f)
        print(f"pickle 파일 로드 완료: {file_path}")
        print(f"데이터 크기: {data.shape}")
        return data
    except Exception as e:
        print(f"pickle 파일 로드 오류: {e}")
        return None
    

def detect_column_mismatches(file_path, file_pattern='*.xlsx', skiprows=None, header=0, verbose=True):
    """
    Excel 파일들을 병합할 때 컬럼명 불일치를 감지하는 함수
    
    Parameters:
    - file_path: 파일들이 있는 경로
    - file_pattern: 파일 패턴 (기본값: '*.xlsx')
    - skiprows: 건너뛸 행 수
    - header: 헤더 행 번호
    - verbose: 상세 출력 여부
    
    Returns:
    - column_info: 각 파일의 컬럼 정보
    - mismatch_report: 불일치 보고서
    """
    import os
    import glob
    import pandas as pd
    from collections import defaultdict
    
    # 디렉토리 존재 확인
    if not os.path.exists(file_path):
        print(f"오류: 경로가 존재하지 않습니다: {file_path}")
        return None, None
    
    # 작업 디렉토리 변경
    original_dir = os.getcwd()
    os.chdir(file_path)
    
    try:
        # 파일 목록 가져오기
        flist = glob.glob(file_pattern)
        
        if verbose:
            print(f"경로: {file_path}")
            print(f"파일 패턴: {file_pattern}")
            print(f"발견된 파일 수: {len(flist)}")
        
        if len(flist) == 0:
            print(f"오류: 패턴 '{file_pattern}'에 맞는 파일이 없습니다.")
            return None, None
        
        # 각 파일의 컬럼 정보 수집
        column_info = {}
        all_columns = set()
        
        for f_nm in flist:
            try:
                df = pd.read_excel(f_nm, 
                                  sheet_name=0,  # 첫 번째 시트만
                                  skiprows=skiprows,
                                  header=header)
                
                columns = list(df.columns)
                column_info[f_nm] = {
                    'columns': columns,
                    'shape': df.shape,
                    'column_count': len(columns)
                }
                all_columns.update(columns)
                
                if verbose:
                    print(f"✓ 읽기 성공: {f_nm} (컬럼 수: {len(columns)})")
                    
            except Exception as e:
                if verbose:
                    print(f"✗ 읽기 실패 ({f_nm}): {e}")
                column_info[f_nm] = {'error': str(e)}
        
        # 불일치 분석
        mismatch_report = {
            'total_files': len(flist),
            'successful_files': len([f for f in column_info.values() if 'error' not in f]),
            'all_unique_columns': sorted(list(all_columns)),
            'column_frequency': defaultdict(list),
            'files_by_column_count': defaultdict(list),
            'missing_columns_by_file': {},
            'extra_columns_by_file': {}
        }
        
        # 각 컬럼이 몇 개 파일에 있는지 계산
        for f_nm, info in column_info.items():
            if 'error' in info:
                continue
                
            columns = info['columns']
            column_count = info['column_count']
            
            # 컬럼별 빈도수
            for col in columns:
                mismatch_report['column_frequency'][col].append(f_nm)
            
            # 컬럼 수별 파일 분류
            mismatch_report['files_by_column_count'][column_count].append(f_nm)
        
        # 각 파일별 누락/추가 컬럼 분석
        most_common_columns = set()
        if mismatch_report['column_frequency']:
            # 50% 이상의 파일에 있는 컬럼들을 '일반적인' 컬럼으로 간주
            threshold = len(flist) * 0.5
            most_common_columns = {
                col for col, files in mismatch_report['column_frequency'].items() 
                if len(files) >= threshold
            }
        
        for f_nm, info in column_info.items():
            if 'error' in info:
                continue
                
            file_columns = set(info['columns'])
            
            # 누락된 컬럼 (일반적인 컬럼 중에 없는 것)
            missing = most_common_columns - file_columns
            if missing:
                mismatch_report['missing_columns_by_file'][f_nm] = sorted(list(missing))
            
            # 추가된 컬럼 (일반적이지 않은 컬럼)
            extra = file_columns - most_common_columns
            if extra:
                mismatch_report['extra_columns_by_file'][f_nm] = sorted(list(extra))
        
        # 결과 출력
        if verbose:
            print(f"\n=== 컬럼 불일치 분석 결과 ===")
            print(f"총 파일 수: {mismatch_report['total_files']}")
            print(f"성공적으로 읽은 파일 수: {mismatch_report['successful_files']}")
            print(f"고유 컬럼 수: {len(mismatch_report['all_unique_columns'])}")
            
            print(f"\n--- 컬럼 수별 파일 분포 ---")
            for col_count, files in sorted(mismatch_report['files_by_column_count'].items()):
                print(f"컬럼 {col_count}개: {len(files)}개 파일")
            
            print(f"\n--- 가장 일반적인 컬럼들 (50% 이상 파일에 존재) ---")
            for col in sorted(most_common_columns):
                file_count = len(mismatch_report['column_frequency'][col])
                print(f"{col}: {file_count}개 파일")
            
            if mismatch_report['missing_columns_by_file']:
                print(f"\n--- 누락된 컬럼이 있는 파일들 ---")
                for f_nm, missing_cols in mismatch_report['missing_columns_by_file'].items():
                    print(f"{f_nm}: {missing_cols}")
            
            if mismatch_report['extra_columns_by_file']:
                print(f"\n--- 추가 컬럼이 있는 파일들 ---")
                for f_nm, extra_cols in mismatch_report['extra_columns_by_file'].items():
                    print(f"{f_nm}: {extra_cols}")
        
        return column_info, mismatch_report
        
    except Exception as e:
        print(f"오류 발생: {e}")
        return None, None
        
    finally:
        # 원래 디렉토리로 복원
        os.chdir(original_dir)
