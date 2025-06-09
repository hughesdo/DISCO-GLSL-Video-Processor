#!/usr/bin/env python3
"""
Shader Test Runner - Automated testing of all GLSL shaders
Renders 250-frame previews of each shader with random video/audio inputs
"""

import json
import random
import logging
from pathlib import Path
import time
import sys
from shader_video_processor import ShaderVideoProcessor

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('shader_test_log.txt'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class ShaderTestRunner:
    def __init__(self):
        """Initialize the shader test runner"""
        self.shader_dir = Path("Shaders")
        self.videos_dir = Path("Videos")
        self.outputs_dir = Path("Outputs")
        self.config_file = self.shader_dir / "shader_config.json"
        
        # Test settings
        self.preview_frames = 250
        self.test_resolution = (1280, 720)
        
        # Create outputs directory
        self.outputs_dir.mkdir(exist_ok=True)
        
        # Load shader configuration
        self.shader_config = self._load_shader_config()
        
        # Find available input files
        self.video_files = self._find_video_files()
        self.audio_files = self._find_audio_files()
        
        logger.info(f"Shader Test Runner initialized")
        logger.info(f"Found {len(self.shader_config)} shaders to test")
        logger.info(f"Found {len(self.video_files)} video files")
        logger.info(f"Found {len(self.audio_files)} audio files")

    def _load_shader_config(self):
        """Load shader configuration from JSON file"""
        try:
            if self.config_file.exists():
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                logger.info(f"Loaded configuration for {len(config)} shaders")
                return config
            else:
                logger.error(f"Shader config file not found: {self.config_file}")
                return {}
        except Exception as e:
            logger.error(f"Failed to load shader config: {e}")
            return {}

    def _find_video_files(self):
        """Find all video files in Videos directory"""
        video_extensions = ['.mp4', '.avi', '.mov', '.mkv', '.webm']
        video_files = []
        
        if self.videos_dir.exists():
            for ext in video_extensions:
                video_files.extend(self.videos_dir.glob(f"*{ext}"))
                video_files.extend(self.videos_dir.glob(f"*{ext.upper()}"))
        
        logger.info(f"Found video files: {[f.name for f in video_files]}")
        return video_files

    def _find_audio_files(self):
        """Find all audio files in Videos directory"""
        audio_extensions = ['.mp3', '.wav', '.m4a', '.aac', '.ogg']
        audio_files = []
        
        if self.videos_dir.exists():
            for ext in audio_extensions:
                audio_files.extend(self.videos_dir.glob(f"*{ext}"))
                audio_files.extend(self.videos_dir.glob(f"*{ext.upper()}"))
        
        logger.info(f"Found audio files: {[f.name for f in audio_files]}")
        return audio_files

    def _get_random_inputs(self):
        """Select random video and audio files for testing"""
        if not self.video_files:
            raise Exception("No video files found in Videos directory")
        if not self.audio_files:
            raise Exception("No audio files found in Videos directory")
        
        video_file = random.choice(self.video_files)
        audio_file = random.choice(self.audio_files)
        
        return video_file, audio_file

    def _get_shader_defaults(self, shader_name):
        """Get default uniform values for a shader"""
        if shader_name not in self.shader_config:
            logger.warning(f"No configuration found for shader: {shader_name}")
            return {}
        
        config = self.shader_config[shader_name]
        defaults = config.get('uniforms', {})
        
        logger.info(f"Using defaults for {shader_name}: {defaults}")
        return defaults

    def _get_audio_settings(self, shader_name):
        """Get audio settings based on shader type"""
        if shader_name not in self.shader_config:
            return {'reactivity_preset': 'moderate'}
        
        config = self.shader_config[shader_name]
        is_audio_reactive = config.get('audioReactive', True)
        
        if is_audio_reactive:
            return {
                'reactivity_preset': 'moderate',
                'beat_sensitivity': 1.0,
                'bass_response': 1.0,
                'mid_response': 1.0,
                'treble_response': 1.0
            }
        else:
            return {'reactivity_preset': 'none'}

    def test_shader(self, shader_name):
        """Test a single shader with random inputs"""
        try:
            logger.info(f"\n{'='*60}")
            logger.info(f"TESTING SHADER: {shader_name}")
            logger.info(f"{'='*60}")
            
            # Get random input files
            video_file, audio_file = self._get_random_inputs()
            logger.info(f"Video input: {video_file.name}")
            logger.info(f"Audio input: {audio_file.name}")
            
            # Get shader defaults and audio settings
            uniforms = self._get_shader_defaults(shader_name)
            audio_settings = self._get_audio_settings(shader_name)
            
            # Create output filename
            shader_base_name = shader_name.replace('.glsl', '')
            output_file = self.outputs_dir / f"{shader_base_name}.mp4"
            
            # Create progress tracker for this test
            progress_tracker = TestProgressTracker(shader_name)
            
            # Create processor
            processor = ShaderVideoProcessor(
                video_path=video_file,
                audio_path=audio_file,
                shader_path=self.shader_dir / shader_name,
                output_path=output_file,
                extra_uniforms=uniforms,
                progress_tracker=progress_tracker,
                audio_settings=audio_settings,
                max_frames=self.preview_frames
            )
            
            # Run the test
            start_time = time.time()
            logger.info(f"Starting processing...")
            
            processor.run()
            
            end_time = time.time()
            duration = end_time - start_time
            
            # Check if output was created
            if output_file.exists():
                file_size = output_file.stat().st_size / (1024 * 1024)  # MB
                logger.info(f"✅ SUCCESS: {shader_name}")
                logger.info(f"   Output: {output_file.name}")
                logger.info(f"   Size: {file_size:.1f} MB")
                logger.info(f"   Duration: {duration:.1f} seconds")
                return True
            else:
                logger.error(f"❌ FAILED: {shader_name} - No output file created")
                return False
                
        except Exception as e:
            logger.error(f"❌ ERROR: {shader_name} - {str(e)}")
            return False

    def run_all_tests(self):
        """Run tests for all shaders"""
        logger.info(f"\n🚀 STARTING SHADER TEST SUITE")
        logger.info(f"Testing {len(self.shader_config)} shaders")
        logger.info(f"Preview frames: {self.preview_frames}")
        logger.info(f"Output directory: {self.outputs_dir}")
        
        start_time = time.time()
        results = {}
        
        for i, shader_name in enumerate(self.shader_config.keys(), 1):
            logger.info(f"\n[{i}/{len(self.shader_config)}] Testing {shader_name}")
            
            success = self.test_shader(shader_name)
            results[shader_name] = success
            
            # Brief pause between tests
            time.sleep(1)
        
        # Generate summary report
        self._generate_summary_report(results, time.time() - start_time)
        
        return results

    def _generate_summary_report(self, results, total_duration):
        """Generate a summary report of all test results"""
        successful = [name for name, success in results.items() if success]
        failed = [name for name, success in results.items() if not success]
        
        logger.info(f"\n{'='*80}")
        logger.info(f"SHADER TEST SUITE COMPLETE")
        logger.info(f"{'='*80}")
        logger.info(f"Total shaders tested: {len(results)}")
        logger.info(f"Successful: {len(successful)}")
        logger.info(f"Failed: {len(failed)}")
        logger.info(f"Success rate: {len(successful)/len(results)*100:.1f}%")
        logger.info(f"Total duration: {total_duration/60:.1f} minutes")
        
        if successful:
            logger.info(f"\n✅ SUCCESSFUL SHADERS:")
            for shader in successful:
                logger.info(f"   - {shader}")
        
        if failed:
            logger.info(f"\n❌ FAILED SHADERS:")
            for shader in failed:
                logger.info(f"   - {shader}")
        
        # Save detailed report to file
        report_file = self.outputs_dir / "test_report.txt"
        with open(report_file, 'w') as f:
            f.write(f"Shader Test Suite Report\n")
            f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"Total shaders tested: {len(results)}\n")
            f.write(f"Successful: {len(successful)}\n")
            f.write(f"Failed: {len(failed)}\n")
            f.write(f"Success rate: {len(successful)/len(results)*100:.1f}%\n")
            f.write(f"Total duration: {total_duration/60:.1f} minutes\n\n")
            
            f.write("Successful shaders:\n")
            for shader in successful:
                f.write(f"  ✅ {shader}\n")
            
            f.write("\nFailed shaders:\n")
            for shader in failed:
                f.write(f"  ❌ {shader}\n")
        
        logger.info(f"\nDetailed report saved to: {report_file}")

class TestProgressTracker:
    """Simple progress tracker for individual shader tests"""
    def __init__(self, shader_name):
        self.shader_name = shader_name
        self.last_progress = 0

    def update(self, progress=None, stage=None, message=None, details=None, **kwargs):
        if progress is not None and progress - self.last_progress >= 20:
            logger.info(f"   Progress: {progress:.0f}% - {stage or 'processing'}")
            self.last_progress = progress

def main():
    """Main entry point for the shader test runner"""
    import argparse

    parser = argparse.ArgumentParser(description='Automated GLSL Shader Test Runner')
    parser.add_argument('--shader', '-s', type=str, help='Test specific shader only')
    parser.add_argument('--frames', '-f', type=int, default=250, help='Number of frames to render (default: 250)')
    parser.add_argument('--list', '-l', action='store_true', help='List available shaders and exit')
    parser.add_argument('--category', '-c', type=str, help='Test only shaders from specific category')

    args = parser.parse_args()

    try:
        # Create test runner
        runner = ShaderTestRunner()
        runner.preview_frames = args.frames

        # Handle list command
        if args.list:
            print("\nAvailable shaders:")
            for shader_name, config in runner.shader_config.items():
                category = config.get('category', 'unknown')
                audio_reactive = config.get('audioReactive', True)
                audio_str = "audio-reactive" if audio_reactive else "non-audio-reactive"
                print(f"  {shader_name:<30} [{category}] ({audio_str})")
            return

        # Handle single shader test
        if args.shader:
            shader_name = args.shader
            if not shader_name.endswith('.glsl'):
                shader_name += '.glsl'

            if shader_name not in runner.shader_config:
                logger.error(f"Shader not found: {shader_name}")
                logger.info("Use --list to see available shaders")
                return

            logger.info(f"Testing single shader: {shader_name}")
            success = runner.test_shader(shader_name)

            if success:
                logger.info(f"✅ Test completed successfully!")
            else:
                logger.error(f"❌ Test failed!")
            return

        # Handle category filter
        if args.category:
            filtered_config = {
                name: config for name, config in runner.shader_config.items()
                if config.get('category', '').lower() == args.category.lower()
            }

            if not filtered_config:
                logger.error(f"No shaders found in category: {args.category}")
                categories = set(config.get('category', 'unknown') for config in runner.shader_config.values())
                logger.info(f"Available categories: {', '.join(sorted(categories))}")
                return

            logger.info(f"Testing {len(filtered_config)} shaders from category: {args.category}")
            runner.shader_config = filtered_config

        # Run all tests
        results = runner.run_all_tests()

        # Exit with appropriate code
        failed_count = sum(1 for success in results.values() if not success)
        if failed_count == 0:
            logger.info("🎉 All tests passed!")
            sys.exit(0)
        else:
            logger.warning(f"⚠️  {failed_count} tests failed")
            sys.exit(1)

    except KeyboardInterrupt:
        logger.info("\n⏹️  Test run interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"💥 Test runner failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
